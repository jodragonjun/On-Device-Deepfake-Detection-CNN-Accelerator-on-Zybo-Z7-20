`timescale 1ns/1ps

module accumulator (
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

input signed [31:0] in0;
input signed [31:0] in1;
input signed [31:0] in2;
input signed [31:0] in3;

/*
    Conv1 raw product 누산용 accumulator.

    in0~in3 : Q16.16 raw product
    acc     : Q16.16 누산값

    Conv1 한 output당 총 27개 product:
    3x3x3 = 27
    4-lane 기준 9번 valid_in 후 valid_out 발생.
*/
output reg signed [47:0] acc;
output reg valid_out;

reg [3:0] mac_count;

wire signed [47:0] in0_ext;
wire signed [47:0] in1_ext;
wire signed [47:0] in2_ext;
wire signed [47:0] in3_ext;

wire signed [47:0] sum_in;
wire signed [47:0] acc_next;

assign in0_ext = {{16{in0[31]}}, in0};
assign in1_ext = {{16{in1[31]}}, in1};
assign in2_ext = {{16{in2[31]}}, in2};
assign in3_ext = {{16{in3[31]}}, in3};

assign sum_in   = in0_ext + in1_ext + in2_ext + in3_ext;
assign acc_next = acc + sum_in;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        acc       <= 48'sd0;
        mac_count <= 4'd0;
        valid_out <= 1'b0;
    end
    else begin
        valid_out <= 1'b0;

        if (acc_rst) begin
            acc       <= 48'sd0;
            mac_count <= 4'd0;
            valid_out <= 1'b0;
        end
        else begin
            if (valid_in) begin
                acc <= acc_next;

                if (mac_count == 4'd8) begin
                    mac_count <= 4'd0;
                    valid_out <= 1'b1;
                end
                else begin
                    mac_count <= mac_count + 4'd1;
                end
            end
        end
    end
end

endmodule