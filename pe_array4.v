module pe_array4 (
    input clk,
    input rst,
    input valid_in,

    input signed [15:0] a0,
    input signed [15:0] a1,
    input signed [15:0] a2,
    input signed [15:0] a3,

    input signed [15:0] b0,
    input signed [15:0] b1,
    input signed [15:0] b2,
    input signed [15:0] b3,

    output signed [31:0] o0,
    output signed [31:0] o1,
    output signed [31:0] o2,
    output signed [31:0] o3,

    output valid_out
);

    wire v0;
    wire v1;
    wire v2;
    wire v3;

    pe u0 (
        clk,
        rst,
        valid_in,
        a0,
        b0,
        o0,
        v0
    );

    pe u1 (
        clk,
        rst,
        valid_in,
        a1,
        b1,
        o1,
        v1
    );

    pe u2 (
        clk,
        rst,
        valid_in,
        a2,
        b2,
        o2,
        v2
    );

    pe u3 (
        clk,
        rst,
        valid_in,
        a3,
        b3,
        o3,
        v3
    );

    assign valid_out = v0;

endmodule