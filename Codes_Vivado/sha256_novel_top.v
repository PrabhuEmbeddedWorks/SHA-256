`timescale 1ns / 1ps

module sha256_novel_top (
    input wire clk,
    input wire rst_n,
    
    // Control Interface
    input wire init,
    input wire next,
    input wire mode,
    
    // Data Interface (Dual Stream)
    input wire [511:0] block_a,
    input wire [511:0] block_b,
    
    // Status Interface
    output wire ready,
    output reg digest_valid,
    output wire [255:0] digest_a,
    output wire [255:0] digest_b
);

    // Initial Hash Constants (H0)
    wire [31:0] H0_0 = 32'h6a09e667;
    wire [31:0] H0_1 = 32'hbb67ae85;
    wire [31:0] H0_2 = 32'h3c6ef372;
    wire [31:0] H0_3 = 32'ha54ff53a;
    wire [31:0] H0_4 = 32'h510e527f;
    wire [31:0] H0_5 = 32'h9b05688c;
    wire [31:0] H0_6 = 32'h1f83d9ab;
    wire [31:0] H0_7 = 32'h5be0cd19;

    // Hash State Registers
    reg [31:0] H_A [0:7];
    reg [31:0] H_B [0:7];
    
    // W Memory Connections
    wire [5:0] w_addr;
    wire [31:0] w_data_0, w_data_1;
    wire thread_sel_core;
    
    // Core Connections
    wire [255:0] core_digest_a;
    wire [255:0] core_digest_b;
    wire core_ready, core_valid;
    
    // Core Instantiation
    sha256_novel_core u_core (
        .clk(clk), .rst_n(rst_n), .init(init), .next(next), .mode(mode),
        .block_in(512'b0), // Unused in core, W mem handles it
        
        // Flattened Inputs (Bypass H_A during init to avoid 1-cycle delay)
        .H_in_a_0(init ? H0_0 : H_A[0]), .H_in_a_1(init ? H0_1 : H_A[1]), 
        .H_in_a_2(init ? H0_2 : H_A[2]), .H_in_a_3(init ? H0_3 : H_A[3]),
        .H_in_a_4(init ? H0_4 : H_A[4]), .H_in_a_5(init ? H0_5 : H_A[5]), 
        .H_in_a_6(init ? H0_6 : H_A[6]), .H_in_a_7(init ? H0_7 : H_A[7]),
        
        .H_in_b_0(init ? H0_0 : H_B[0]), .H_in_b_1(init ? H0_1 : H_B[1]), 
        .H_in_b_2(init ? H0_2 : H_B[2]), .H_in_b_3(init ? H0_3 : H_B[3]),
        .H_in_b_4(init ? H0_4 : H_B[4]), .H_in_b_5(init ? H0_5 : H_B[5]), 
        .H_in_b_6(init ? H0_6 : H_B[6]), .H_in_b_7(init ? H0_7 : H_B[7]),
        
        .ready(core_ready), .digest_valid(core_valid),
        .digest_a(core_digest_a), .digest_b(core_digest_b),
        .w_addr(w_addr), .w_data_0(w_data_0), .w_data_1(w_data_1),
        .thread_sel_out(thread_sel_core)
    );

    // W Memory Instantiation
    sha256_w_mem_novel u_w_mem (
        .clk(clk),
        .rst_n(rst_n),
        .init(init),
        .next(~core_ready), // Enable shifting when core is busy
        .block_in_a(block_a),
        .block_in_b(block_b),
        .addr(w_addr),
        .thread_sel(thread_sel_core),
        .w_out_0(w_data_0),
        .w_out_1(w_data_1)
    );
    
    // Hash Accumulation Logic
    // When core_valid is high, we add the core result to H.
    // H_new = H_old + core_digest
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<8; i=i+1) begin
                H_A[i] <= 0;
                H_B[i] <= 0;
            end
            digest_valid <= 0;
        end else if (init) begin
            digest_valid <= 0;
            H_A[0] <= H0_0; H_A[1] <= H0_1; H_A[2] <= H0_2; H_A[3] <= H0_3;
            H_A[4] <= H0_4; H_A[5] <= H0_5; H_A[6] <= H0_6; H_A[7] <= H0_7;
            
            H_B[0] <= H0_0; H_B[1] <= H0_1; H_B[2] <= H0_2; H_B[3] <= H0_3;
            H_B[4] <= H0_4; H_B[5] <= H0_5; H_B[6] <= H0_6; H_B[7] <= H0_7;
        end else if (core_valid && !digest_valid) begin
            digest_valid <= 1;
            // Accumulate
            for (i=0; i<8; i=i+1) begin
                H_A[i] <= H_A[i] + core_digest_a[255 - 32*i -: 32];
                H_B[i] <= H_B[i] + core_digest_b[255 - 32*i -: 32];
            end
        end
    end
    
    assign digest_a = {H_A[0], H_A[1], H_A[2], H_A[3], H_A[4], H_A[5], H_A[6], H_A[7]};
    assign digest_b = {H_B[0], H_B[1], H_B[2], H_B[3], H_B[4], H_B[5], H_B[6], H_B[7]};

endmodule
