`timescale 1ns / 1ps

module sha256_novel_core (
    input wire clk,
    input wire rst_n,
    input wire init,
    input wire next,
    input wire mode, // 0: SHA-224, 1: SHA-256
    input wire [511:0] block_in,
    
    // Initial Hash State Inputs (Flattened)
    input wire [31:0] H_in_a_0, H_in_a_1, H_in_a_2, H_in_a_3, H_in_a_4, H_in_a_5, H_in_a_6, H_in_a_7,
    input wire [31:0] H_in_b_0, H_in_b_1, H_in_b_2, H_in_b_3, H_in_b_4, H_in_b_5, H_in_b_6, H_in_b_7,

    output reg ready,
    output reg digest_valid,
    output reg [255:0] digest_a, // Flattened output of H+a
    output reg [255:0] digest_b,
    
    // W Memory Interface
    output wire [5:0] w_addr,
    input wire [31:0] w_data_0, // W[t]
    input wire [31:0] w_data_1,  // W[t+1]
    output wire thread_sel_out // Expose thread selector for W Mem
);

    // =========================================================================
    // 1. Control Logic & Thread Scheduling
    // =========================================================================
    
    reg [6:0] global_ctr; // 0 to 65
    reg busy;
    reg thread_sel; // 0: Thread A, 1: Thread B
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            global_ctr <= 0;
            busy <= 0;
            thread_sel <= 0;
        end else begin
            if (init) begin
                global_ctr <= 0;
                busy <= 1;
                thread_sel <= 0;
            end else if (busy) begin
                // Toggle thread every cycle
                thread_sel <= ~thread_sel;
                // Increment counter every 2 cycles (since we do A then B for same step)
                if (thread_sel == 1) global_ctr <= global_ctr + 1;
                
                // Termination: Stop when we have done 32 steps (64 rounds)
                // We stop when global_ctr is 32 and we have just finished the second thread (thread_sel was 1, now 0)
                if (global_ctr == 32 && thread_sel == 0) busy <= 0;
            end
        end
    end
    
    assign thread_sel_out = thread_sel;
    
    // Round Number for W Memory
    // Round index = global_ctr[6:1] * 2
    assign w_addr = {global_ctr[5:0], 1'b0}; // Base address for W[t], W[t+1] is implied (Wait, global_ctr counts steps 0..32. 32*2=64 rounds)
    // Actually global_ctr counts 0..64.
    // Step 0 (Thread A): global_ctr=0. w_addr=0.
    // Step 0 (Thread B): global_ctr=0. w_addr=0.
    // Step 1 (Thread A): global_ctr=1. w_addr=2.
    // Step 1 (Thread B): global_ctr=1. w_addr=2.
    // Correct.
    
    // =========================================================================
    // 2. Working Variables (Dual Threaded State)
    // =========================================================================
    
    // Thread A State
    reg [31:0] a_A, b_A, c_A, d_A, e_A, f_A, g_A, h_A;
    // Thread B State
    reg [31:0] a_B, b_B, c_B, d_B, e_B, f_B, g_B, h_B;
    
    // Current Working Variables (Muxed)
    reg [31:0] a, b, c, d, e, f, g, h;
    
    // Pipeline Registers
    reg [31:0] a_reg, b_reg, c_reg, d_reg, e_reg, f_reg, g_reg, h_reg;
    reg [31:0] k1_reg, w1_reg;
    reg        thread_sel_delayed;
    
    always @(*) begin
        if (thread_sel == 0) begin // Thread A is entering Stage 1
            a = a_A; b = b_A; c = c_A; d = d_A; e = e_A; f = f_A; g = g_A; h = h_A;
        end else begin // Thread B is entering Stage 1
            a = a_B; b = b_B; c = c_B; d = d_B; e = e_B; f = f_B; g = g_B; h = h_B;
        end
    end

    // =========================================================================
    // 3. Unrolled Logic (2 Rounds)
    // =========================================================================
    
    // Functions
    function [31:0] Ch(input [31:0] x, y, z);
        Ch = (x & y) ^ (~x & z);
    endfunction

    function [31:0] Maj(input [31:0] x, y, z);
        Maj = (x & y) ^ (x & z) ^ (y & z);
    endfunction

    function [31:0] S0(input [31:0] x);
        S0 = {x[1:0], x[31:2]} ^ {x[12:0], x[31:13]} ^ {x[21:0], x[31:22]};
    endfunction

    function [31:0] S1(input [31:0] x);
        S1 = {x[5:0], x[31:6]} ^ {x[10:0], x[31:11]} ^ {x[24:0], x[31:25]};
    endfunction

    // K Constants
    wire [31:0] k0, k1;
    sha256_k_constants u_k (
        .round(w_addr),
        .K(k0)
    );
    sha256_k_constants u_k1 (
        .round({w_addr[5:1], 1'b1}), // w_addr + 1
        .K(k1)
    );

    // --- Round 1 Logic (t) ---
    wire [31:0] s1_e = S1(e);
    wire [31:0] ch_efg = Ch(e, f, g);
    
    wire [31:0] t1_sum, t1_carry;
    compressor_4to2 u_c1 (
        .x1(h), .x2(s1_e), .x3(ch_efg), .x4(k0), .cin(1'b0),
        .sum(t1_sum), .carry(t1_carry), .cout()
    );
    
    wire [31:0] s0_a = S0(a);
    wire [31:0] maj_abc = Maj(a, b, c);
    wire [31:0] t2 = s0_a + maj_abc;
    
    wire [31:0] t1 = t1_sum + t1_carry + w_data_0;
    
    wire [31:0] a_next = t1 + t2;
    wire [31:0] e_next = d + t1;
    wire [31:0] b_next = a;
    wire [31:0] c_next = b;
    wire [31:0] d_next = c;
    wire [31:0] f_next = e;
    wire [31:0] g_next = f;
    wire [31:0] h_next = g;
    
    // --- Round 2 Logic (t+1) ---
    // Stage 2 Logic (Combinatorial from Regs)
    wire [31:0] s1_e_2 = S1(e_reg);
    wire [31:0] ch_efg_2 = Ch(e_reg, f_reg, g_reg);
    
    wire [31:0] t1_sum_2, t1_carry_2;
    compressor_4to2 u_c2 (
        .x1(h_reg), .x2(s1_e_2), .x3(ch_efg_2), .x4(k1_reg), .cin(1'b0),
        .sum(t1_sum_2), .carry(t1_carry_2), .cout()
    );
    
    wire [31:0] t1_2 = t1_sum_2 + t1_carry_2 + w1_reg;
    
    wire [31:0] s0_a_2 = S0(a_reg);
    wire [31:0] maj_abc_2 = Maj(a_reg, b_reg, c_reg);
    wire [31:0] t2_2 = s0_a_2 + maj_abc_2;
    
    wire [31:0] a_final = t1_2 + t2_2;
    wire [31:0] e_final = d_reg + t1_2;
    wire [31:0] b_final = a_reg;
    wire [31:0] c_final = b_reg;
    wire [31:0] d_final = c_reg;
    wire [31:0] f_final = e_reg;
    wire [31:0] g_final = f_reg;
    wire [31:0] h_final = g_reg;

    // =========================================================================
    // 4. State Update (Write Back)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 0; b_reg <= 0; c_reg <= 0; d_reg <= 0;
            e_reg <= 0; f_reg <= 0; g_reg <= 0; h_reg <= 0;
            k1_reg <= 0; w1_reg <= 0;
            thread_sel_delayed <= 0;
            
            a_A <= 0; b_A <= 0; c_A <= 0; d_A <= 0; e_A <= 0; f_A <= 0; g_A <= 0; h_A <= 0;
            a_B <= 0; b_B <= 0; c_B <= 0; d_B <= 0; e_B <= 0; f_B <= 0; g_B <= 0; h_B <= 0;
            
            ready <= 1;
            digest_valid <= 0;
        end else begin
            // Pipeline Register Update
            if (busy) begin
                a_reg <= a_next; b_reg <= b_next; c_reg <= c_next; d_reg <= d_next;
                e_reg <= e_next; f_reg <= f_next; g_reg <= g_next; h_reg <= h_next;
                k1_reg <= k1;
                w1_reg <= w_data_1;
                thread_sel_delayed <= thread_sel;
            end
            
            // Initialization
            if (init) begin
                // Initialize Working Variables from H_in
                a_A <= H_in_a_0; b_A <= H_in_a_1; c_A <= H_in_a_2; d_A <= H_in_a_3;
                e_A <= H_in_a_4; f_A <= H_in_a_5; g_A <= H_in_a_6; h_A <= H_in_a_7;
                
                a_B <= H_in_b_0; b_B <= H_in_b_1; c_B <= H_in_b_2; d_B <= H_in_b_3;
                e_B <= H_in_b_4; f_B <= H_in_b_5; g_B <= H_in_b_6; h_B <= H_in_b_7;
                
                ready <= 0;
                digest_valid <= 0;
            end 
            // Write Back
            else if (busy) begin
                // Note: global_ctr is incremented every 2 cycles.
                // We need to check if valid data is coming out of pipeline.
                // Pipeline latency is 1 cycle.
                // So if we started at T=0, at T=1 we have result of Round 0/1.
                
                if (thread_sel_delayed == 0) begin // Thread A finished Stage 2
                    a_A <= a_final; b_A <= b_final; c_A <= c_final; d_A <= d_final;
                    e_A <= e_final; f_A <= f_final; g_A <= g_final; h_A <= h_final;
                end else begin // Thread B finished Stage 2
                    a_B <= a_final; b_B <= b_final; c_B <= c_final; d_B <= d_final;
                    e_B <= e_final; f_B <= f_final; g_B <= g_final; h_B <= h_final;
                end
                
                // Termination Check
                if (global_ctr == 32) begin 
                     if (thread_sel_delayed == 1) begin // Both threads finished last step
                        ready <= 1;
                        digest_valid <= 1;
                        // busy <= 0; // Removed: Handled in first always block
                     end
                end
            end
        end
    end
    
    // Output Assignment
    always @(*) begin
        digest_a = {a_A, b_A, c_A, d_A, e_A, f_A, g_A, h_A};
        digest_b = {a_B, b_B, c_B, d_B, e_B, f_B, g_B, h_B};
    end

endmodule
