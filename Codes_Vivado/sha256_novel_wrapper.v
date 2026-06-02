`timescale 1ns / 1ps

module sha256_novel_wrapper (
    input wire clk,
    input wire rst_n,
    input wire init,
    input wire next,
    input wire mode,
    input wire [31:0] data_in, // Serial input to load blocks
    output wire [31:0] data_out, // Serial output to read digests
    output wire ready,
    output wire digest_valid
);

    // Internal Registers for Blocks
    reg [511:0] block_a;
    reg [511:0] block_b;
    
    // Internal Wires for Digests
    wire [255:0] digest_a;
    wire [255:0] digest_b;
    
    // Simple shift register to load data
    always @(posedge clk) begin
        if (init) begin
            block_a <= {block_a[479:0], data_in};
            block_b <= {block_b[479:0], block_a[511:480]}; // Daisy chain
        end
    end
    
    // Instantiate Top
    sha256_novel_top u_top (
        .clk(clk),
        .rst_n(rst_n),
        .init(init),
        .next(next),
        .mode(mode),
        .block_a(block_a),
        .block_b(block_b),
        .ready(ready),
        .digest_valid(digest_valid),
        .digest_a(digest_a),
        .digest_b(digest_b)
    );
    
    // Output Mux
    assign data_out = digest_a[31:0] ^ digest_b[31:0]; // Just XOR to reduce pins

endmodule
