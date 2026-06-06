`timescale 1ns/1ps

module conv2_accumulator (
    clk,
    rst,
    acc_rst,
    valid_in,

    in0,
    in1,
    in2,
    in3,

    acc,
    valid_out
);

input clk;
input rst;
input acc_rst;
input valid_in;

input signed [47:0] in0;
input signed [47:0] in1;
input signed [47:0] in2;
input signed [47:0] in3;

/*
    Conv2 raw product 누산용 accumulator.

    in0~in3 : Q16.16 raw product
              32-bit feature * 16-bit weight = 48-bit product

    acc     : Q16.16 raw accumulation

    Conv2 한 output당 product 수:
        3 * 3 * 32 = 288

    4-lane PE 기준:
        288 / 4 = 72 groups

    따라서 cnt == 71에서 최종 valid_out 발생.
*/
output reg signed [63:0] acc;
output reg valid_out;

parameter [6:0] COUNT_LAST = 7'd71;

reg [6:0] cnt;

wire signed [63:0] in0_ext;
wire signed [63:0] in1_ext;
wire signed [63:0] in2_ext;
wire signed [63:0] in3_ext;

wire signed [63:0] sum_in;
wire signed [63:0] next_acc;

assign in0_ext = {{16{in0[47]}}, in0};
assign in1_ext = {{16{in1[47]}}, in1};
assign in2_ext = {{16{in2[47]}}, in2};
assign in3_ext = {{16{in3[47]}}, in3};

assign sum_in  = in0_ext + in1_ext + in2_ext + in3_ext;
assign next_acc = acc + sum_in;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        acc <= 64'sd0;
        cnt <= 7'd0;
        valid_out <= 1'b0;
    end
    else begin
        valid_out <= 1'b0;

        if (acc_rst) begin
            acc <= 64'sd0;
            cnt <= 7'd0;
            valid_out <= 1'b0;
        end
        else begin
            if (valid_in) begin
                acc <= next_acc;

                if (cnt == COUNT_LAST) begin
                    cnt <= 7'd0;
                    valid_out <= 1'b1;
                end
                else begin
                    cnt <= cnt + 7'd1;
                end
            end
        end
    end
end

endmodule