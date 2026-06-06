`timescale 1ns/1ps

module pe32x16 (
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

input signed [31:0] a;
input signed [15:0] b;

output reg signed [47:0] out;
output reg valid_out;

reg signed [47:0] mult;
reg valid_d1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mult <= 48'sd0;
        out <= 48'sd0;
        valid_d1 <= 1'b0;
        valid_out <= 1'b0;
    end
    else begin
        /*
            a      : Q8.8 feature
            b      : Q8.8 weight
            mult   : Q16.16 raw product

            기존:
                out <= mult >>> 8;

            수정:
                out <= mult;

            shift는 PE에서 하지 않고,
            Conv2 accumulator에서 raw product를 전부 누산한 뒤
            Conv2 top에서 bias << 8 더하고 마지막에 >>> 8 한다.
        */
        mult <= $signed(a) * $signed(b);
        out <= mult;

        valid_d1 <= valid_in;
        valid_out <= valid_d1;
    end
end

endmodule