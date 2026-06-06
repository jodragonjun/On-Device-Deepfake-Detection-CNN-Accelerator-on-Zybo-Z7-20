`timescale 1ns/1ps

module pe (
    clk,
    rst,
    valid_in,
    a,
    b,
    out,
    valid_out
);

input clk;
input rst;
input valid_in;

input signed [15:0] a;
input signed [15:0] b;

output reg signed [31:0] out;
output reg valid_out;

reg signed [31:0] mult;
reg valid_d1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mult <= 32'sd0;
        out <= 32'sd0;
        valid_d1 <= 1'b0;
        valid_out <= 1'b0;
    end
    else begin
        mult <= $signed(a) * $signed(b);

        /*
            기존:
                out <= mult >>> 8;

            수정:
                raw product 그대로 출력

            a      : Q8.8
            b      : Q8.8
            mult   : Q16.16
            out    : Q16.16 raw product

            따라서 shift는 PE에서 하지 않고,
            Conv accumulator에서 raw product들을 전부 누산한 뒤
            마지막에 >>> 8 해야 한다.
        */
        out <= mult;

        valid_d1 <= valid_in;
        valid_out <= valid_d1;
    end
end

endmodule