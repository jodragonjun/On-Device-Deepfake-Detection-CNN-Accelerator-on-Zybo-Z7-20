`timescale 1ns/1ps

module cnn_full_inference_top (
    clk,
    rst,

    img_wr_en,
    img_wr_addr,
    img_wr_r,
    img_wr_g,
    img_wr_b,

    start,

    final_valid,
    final_pred,
    final_done,
    feature_busy,
    feature_done,
    tail_busy
);

input clk;
input rst;

input img_wr_en;
input [11:0] img_wr_addr;
input signed [15:0] img_wr_r;
input signed [15:0] img_wr_g;
input signed [15:0] img_wr_b;

input start;

output final_valid;
output final_pred;
output final_done;
//output wire signed [95:0] final_logit;

output feature_busy;
output feature_done;
output tail_busy;

//for debug final logit
wire signed [95:0] final_logit;

//////////////////////////////////////////////////
// start pulse
//////////////////////////////////////////////////

reg start_d;
wire start_pulse;

assign start_pulse = start & (~start_d);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        start_d <= 1'b0;
    end
    else begin
        start_d <= start;
    end
end

//////////////////////////////////////////////////
// feature extractor wires
//////////////////////////////////////////////////

wire signed [31:0] pool3_out;
wire pool3_valid;
wire [2:0] pool3_row;
wire [2:0] pool3_col;
wire [6:0] pool3_ch;

wire signed [31:0] dbg_conv3_out;
wire dbg_conv3_valid;
wire [3:0] dbg_conv3_row;
wire [3:0] dbg_conv3_col;
wire [6:0] dbg_conv3_ch;

//////////////////////////////////////////////////
// Conv1 - Pool1 - Conv2 - Pool2 - Conv3 - Pool3
//////////////////////////////////////////////////

conv1_pool1_conv2_pool2_conv3_pool3_top u_feature_extractor (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start_pulse),

    .pool3_out(pool3_out),
    .pool3_valid(pool3_valid),
    .pool3_row(pool3_row),
    .pool3_col(pool3_col),
    .pool3_ch(pool3_ch),

    .busy(feature_busy),
    .done(feature_done),

    .dbg_conv3_out(dbg_conv3_out),
    .dbg_conv3_valid(dbg_conv3_valid),
    .dbg_conv3_row(dbg_conv3_row),
    .dbg_conv3_col(dbg_conv3_col),
    .dbg_conv3_ch(dbg_conv3_ch)
);

//////////////////////////////////////////////////
// GAP - Dense1 - ReLU - Dense2
//////////////////////////////////////////////////

cnn_tail_gap_dense_top u_classifier_tail (
    .clk(clk),
    .rst(rst),
    .start(start_pulse),

    .valid_in(pool3_valid),
    .pool3_data(pool3_out),
    .pool3_row(pool3_row),
    .pool3_col(pool3_col),
    .pool3_ch(pool3_ch),

    .busy(tail_busy),
    .valid_out(final_valid),
    .logit(final_logit),
    .pred(final_pred),
    .done(final_done)
);

endmodule