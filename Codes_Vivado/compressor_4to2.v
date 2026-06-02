`timescale 1ns / 1ps

module compressor_4to2 (
    input  [31:0] x1,
    input  [31:0] x2,
    input  [31:0] x3,
    input  [31:0] x4,
    input         cin,
    output [31:0] sum,
    output [31:0] carry,
    output        cout
);

    // 4:2 Compressor Logic using LUT6 optimization
    // A 4:2 compressor takes 4 inputs + 1 carry-in and produces 2 outputs (Sum, Carry) + 1 carry-out.
    // It is essentially two 3:2 Full Adders (FA) connected in series.
    // FA1: (x1, x2, x3) -> (Sum1, Carry1)
    // FA2: (Sum1, x4, cin) -> (Sum, Carry2)
    // Final Carry = Carry1 + Carry2
    
    // However, for FPGA LUT6, we can map this efficiently.
    // S = x1 ^ x2 ^ x3 ^ x4 ^ cin
    // C = (x1+x2+x3+x4+cin) >= 4 ? ... complex
    
    // Structural implementation using basic logic which synthesis maps to LUTs
    
    wire [31:0] s_int;
    wire [31:0] c_int;
    
    // Layer 1
    wire [31:0] s1 = x1 ^ x2 ^ x3;
    wire [31:0] c1 = (x1 & x2) | (x1 & x3) | (x2 & x3);
    wire [31:0] c1_shifted = {c1[30:0], 1'b0}; // Shift left by 1
    
    // Layer 2
    assign sum = s1 ^ x4 ^ c1_shifted;
    wire [31:0] c2 = (s1 & x4) | (s1 & c1_shifted) | (x4 & c1_shifted);
    assign carry = {c2[30:0], 1'b0}; // Shift left by 1
    
    assign cout = 0; // Unused in vector mode
    
endmodule
