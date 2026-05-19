`timescale 1ns/1ps

module pe32x16_comb (
    a,
    b,
    out
);

input signed [31:0] a;
input signed [15:0] b;
output signed [47:0] out;

wire signed [47:0] mult;

assign mult = a * b;
assign out  = mult >>> 8;

endmodule