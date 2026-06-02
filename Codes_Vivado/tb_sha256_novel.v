`timescale 1ns / 1ps

module tb_sha256_novel;

    // Inputs
    reg clk;
    reg rst_n;
    reg init;
    reg next;
    reg mode;
    reg [511:0] block_a;
    reg [511:0] block_b;

    // Outputs
    wire ready;
    wire digest_valid;
    wire [255:0] digest_a;
    wire [255:0] digest_b;

    // Instantiate the Unit Under Test (UUT)
    sha256_novel_top uut (
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

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        init = 0;
        next = 0;
        mode = 1; // SHA-256
        block_a = 0;
        block_b = 0;

        // Reset
        #100;
        rst_n = 1;
        #20;

        // Test Case: "abc"
        // Message: "abc" (0x616263)
        // Padding: 0x80, then 0s, then length (24 bits = 0x18)
        // Block: 61626380 00...00 00000018
        
        // Stream A: "abc"
        block_a = 512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018;
        
        // Stream B: "abc" (Same for verification)
        block_b = 512'h534A4345800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020;

        // Start Hashing
        #10;
        init = 1;
        #20;
        init = 0;
        
        // Wait for completion
        wait(digest_valid);
        #20;
        
        // Check Results
        // Expected SHA-256("abc") = ba7816bf 8f01cfea 414140de 5dae2223 b00361a3 96177a9c b410ff61 f20015ad
        
        $display("Stream A Digest: %h", digest_a);
        $display("Stream B Digest: %h", digest_b);
        
        if (digest_a == 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad)
            $display("Stream A: PASS");
        else
            $display("Stream A: FAIL");
            
        if (digest_b == 256'h09ba7ac2d4333eb3878c05f75ff0e844bce8f461028f1ebb14757489a86d108b)
            $display("Stream B: PASS");
        else
            $display("Stream B: FAIL");
            
        $finish;
    end
      
endmodule
