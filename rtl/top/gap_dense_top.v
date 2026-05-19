`timescale 1ns/1ps

module cnn_tail_gap_dense_top (
    clk,
    rst,
    start,

    valid_in,
    pool3_data,
    pool3_row,
    pool3_col,
    pool3_ch,

    busy,
    valid_out,
    logit,
    pred,
    done
);

input clk;
input rst;
input start;

input valid_in;
input signed [31:0] pool3_data;
input [2:0] pool3_row;
input [2:0] pool3_col;
input [6:0] pool3_ch;

output busy;
output valid_out;
output signed [95:0] logit;
output pred;
output done;

wire gap_busy;
wire gap_valid;
wire signed [63:0] gap_data;
wire [6:0] gap_ch;
wire gap_done;

wire dense1_busy;
wire dense1_valid;
wire signed [63:0] dense1_data;
wire [5:0] dense1_idx;
wire dense1_done;

wire dense2_busy;
wire dense2_valid;
wire signed [95:0] dense2_logit;
wire dense2_pred;
wire dense2_done;

assign busy = gap_busy | dense1_busy | dense2_busy;
assign valid_out = dense2_valid;
assign logit = dense2_logit;
assign pred = dense2_pred;
assign done = dense2_done;

global_avg_pool_6x6_128 u_gap (
    .clk(clk),
    .rst(rst),
    .start(start),

    .valid_in(valid_in),
    .in_data(pool3_data),
    .in_row(pool3_row),
    .in_col(pool3_col),
    .in_ch(pool3_ch),

    .busy(gap_busy),
    .valid_out(gap_valid),
    .out_data(gap_data),
    .out_ch(gap_ch),
    .done(gap_done)
);

dense1_128x64_relu u_dense1 (
    .clk(clk),
    .rst(rst),

    .valid_in(gap_valid),
    .in_data(gap_data),
    .in_idx(gap_ch),

    .busy(dense1_busy),
    .valid_out(dense1_valid),
    .out_data(dense1_data),
    .out_idx(dense1_idx),
    .done(dense1_done)
);

dense2_64x1 u_dense2 (
    .clk(clk),
    .rst(rst),

    .valid_in(dense1_valid),
    .in_data(dense1_data),
    .in_idx(dense1_idx),

    .busy(dense2_busy),
    .valid_out(dense2_valid),
    .logit(dense2_logit),
    .pred(dense2_pred),
    .done(dense2_done)
);

endmodule