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

/*
    a    : Q8.8 feature
    b    : Q8.8 weight
    mult : Q16.16 raw product

    기존:
        out = mult >>> 8;

    수정:
        out = mult;

    shift는 Conv3 top에서 모든 raw product를 누산한 뒤
    bias << 8 더하고 마지막에 >>> 8 한다.
*/
assign mult = $signed(a) * $signed(b);
assign out  = mult;

endmodule