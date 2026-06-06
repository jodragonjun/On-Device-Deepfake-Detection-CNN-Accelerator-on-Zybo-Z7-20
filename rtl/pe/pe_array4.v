`timescale 1ns/1ps

module pe_array4 (
    clk,
    rst,
    valid_in,

    a0,
    a1,
    a2,
    a3,

    b0,
    b1,
    b2,
    b3,

    o0,
    o1,
    o2,
    o3,

    valid_out
);

input clk;
input rst;
input valid_in;

input signed [15:0] a0;
input signed [15:0] a1;
input signed [15:0] a2;
input signed [15:0] a3;

input signed [15:0] b0;
input signed [15:0] b1;
input signed [15:0] b2;
input signed [15:0] b3;

output signed [31:0] o0;
output signed [31:0] o1;
output signed [31:0] o2;
output signed [31:0] o3;

output valid_out;

wire v0;
wire v1;
wire v2;
wire v3;

/*
    pe 출력 의미:
    기존: (a * b) >>> 8  = Q8.8
    수정:  a * b          = Q16.16 raw product
*/

pe u0 (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .a(a0),
    .b(b0),
    .out(o0),
    .valid_out(v0)
);

pe u1 (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .a(a1),
    .b(b1),
    .out(o1),
    .valid_out(v1)
);

pe u2 (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .a(a2),
    .b(b2),
    .out(o2),
    .valid_out(v2)
);

pe u3 (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .a(a3),
    .b(b3),
    .out(o3),
    .valid_out(v3)
);

assign valid_out = v0;

endmodule