`timescale 1ns / 1ps

module sha256_w_mem_novel (
    input wire clk,
    input wire rst_n,
    input wire init,
    input wire next,
    input wire [511:0] block_in_a,
    input wire [511:0] block_in_b,
    input wire [5:0] addr, // Base address t (0, 2, 4... 62)
    input wire thread_sel, // 0: A, 1: B
    
    output wire [31:0] w_out_0, // W[t]
    output wire [31:0] w_out_1  // W[t+1]
);

    // We need to store 16 words for Thread A and 16 words for Thread B.
    // And we need to expand them on the fly.
    // Since we access W[t] and W[t+1] simultaneously, and we update them.
    
    // For rounds 0-15: Direct read from block.
    // For rounds 16-63: Compute W[t] = sigma1(W[t-2]) + W[t-7] + sigma0(W[t-15]) + W[t-16]
    
    // Dual Threading Strategy:
    // We have 2 separate memories: w_mem_a and w_mem_b.
    // Each is a sliding window of 16 words.
    
    reg [31:0] w_mem_a [0:15];
    reg [31:0] w_mem_b [0:15];
    
    // Functions
    function [31:0] sigma0(input [31:0] x);
        sigma0 = {x[6:0], x[31:7]} ^ {x[17:0], x[31:18]} ^ (x >> 3);
    endfunction

    function [31:0] sigma1(input [31:0] x);
        sigma1 = {x[16:0], x[31:17]} ^ {x[18:0], x[31:19]} ^ (x >> 10);
    endfunction

    // Logic
    // When init is high, we load the blocks.
    // When running, we shift and compute new values.
    // But we only update the memory for the ACTIVE thread.
    // Thread A is active on even cycles (thread_sel=0).
    // Thread B is active on odd cycles (thread_sel=1).
    
    // We need to produce W[t] and W[t+1].
    // For t < 16: W[t] = w_mem[t], W[t+1] = w_mem[t+1].
    // For t >= 16: We need to compute them.
    // But our sliding window always keeps W[t] at index 0?
    // No, standard sliding window keeps W[t] at index 0?
    // Let's stick to the standard "16 registers" approach where we shift every round.
    // But here we do 2 rounds per step.
    // So we need to shift by 2?
    
    // Let's try a simpler approach:
    // 16 registers w0...w15.
    // In one step (2 rounds), we need to generate w16 and w17, and shift everything by 2.
    // w0_new = w2
    // ...
    // w14_new = w16
    // w15_new = w17
    
    // Calculation:
    // w16 = sigma1(w14) + w9 + sigma0(w1) + w0
    // w17 = sigma1(w15) + w10 + sigma0(w2) + w1
    
    // Note: w17 depends on w15, w10, w2, w1. All available in current window.
    
    integer i;
    
    // New values for Thread A
    wire [31:0] w16_a = sigma1(w_mem_a[14]) + w_mem_a[9] + sigma0(w_mem_a[1]) + w_mem_a[0];
    wire [31:0] w17_a = sigma1(w_mem_a[15]) + w_mem_a[10] + sigma0(w_mem_a[2]) + w_mem_a[1];
    
    // New values for Thread B
    wire [31:0] w16_b = sigma1(w_mem_b[14]) + w_mem_b[9] + sigma0(w_mem_b[1]) + w_mem_b[0];
    wire [31:0] w17_b = sigma1(w_mem_b[15]) + w_mem_b[10] + sigma0(w_mem_b[2]) + w_mem_b[1];
    
    always @(posedge clk) begin
        if (init) begin
            // Load blocks
            for (i=0; i<16; i=i+1) begin
                w_mem_a[i] <= block_in_a[511 - 32*i -: 32];
                w_mem_b[i] <= block_in_b[511 - 32*i -: 32];
            end
        end else if (next) begin
            // Shift logic
            // Only shift if round >= 16?
            // Actually, we can just always shift and feed the "new" values.
            // But for the first 16 rounds (8 steps), we just consume the loaded data.
            // If we shift, we lose the data.
            // Standard approach: The 16 registers HOLD the "current window".
            // So for t=0, regs hold W0..W15. We output W0, W1.
            // Then we shift by 2. Regs hold W2..W17.
            // This works for ALL rounds.
            
            if (thread_sel == 0) begin // Update Thread A
                for (i=0; i<14; i=i+1) w_mem_a[i] <= w_mem_a[i+2];
                w_mem_a[14] <= w16_a;
                w_mem_a[15] <= w17_a;
                //$display("W_Mem_A Update: W16=%h, W17=%h", w16_a, w17_a);
            end else begin // Update Thread B
                for (i=0; i<14; i=i+1) w_mem_b[i] <= w_mem_b[i+2];
                w_mem_b[14] <= w16_b;
                w_mem_b[15] <= w17_b;
            end
        end
        //$display("W_Out: Thread=%d, W0=%h, W1=%h", thread_sel, w_out_0, w_out_1);
    end
    
    // Output Logic
    // We always output w_mem[0] and w_mem[1] of the ACTIVE thread.
    // Because we shift *after* usage?
    // No, we shift at the clock edge.
    // So in Cycle N (Thread A active), we read w_mem_a[0] and [1].
    // At end of Cycle N, we shift w_mem_a.
    // So in Cycle N+2 (Thread A active again), we read w_mem_a[0] (which was old w2) and [1] (old w3).
    // This is correct.
    
    assign w_out_0 = (thread_sel == 0) ? w_mem_a[0] : w_mem_b[0];
    assign w_out_1 = (thread_sel == 0) ? w_mem_a[1] : w_mem_b[1];

endmodule
