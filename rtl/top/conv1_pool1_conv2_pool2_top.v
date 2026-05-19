`timescale 1ns/1ps

module conv1_pool1_conv2_pool2_top (
    clk,
    rst,

    img_wr_en,
    img_wr_addr,
    img_wr_r,
    img_wr_g,
    img_wr_b,

    start,

    pool2_out,
    pool2_valid,
    pool2_row,
    pool2_col,
    pool2_ch,

    busy,
    done,

    dbg_conv2_out,
    dbg_conv2_valid,
    dbg_conv2_row,
    dbg_conv2_col,
    dbg_conv2_ch
);

////////////////////////////////////////////////////////////
// Port
////////////////////////////////////////////////////////////
input clk;
input rst;

input img_wr_en;
input [11:0] img_wr_addr;
input signed [15:0] img_wr_r;
input signed [15:0] img_wr_g;
input signed [15:0] img_wr_b;

input start;

output signed [31:0] pool2_out;
output pool2_valid;
output [3:0] pool2_row;
output [3:0] pool2_col;
output [5:0] pool2_ch;

output busy;
output reg done;

output signed [31:0] dbg_conv2_out;
output dbg_conv2_valid;
output [4:0] dbg_conv2_row;
output [4:0] dbg_conv2_col;
output [5:0] dbg_conv2_ch;

////////////////////////////////////////////////////////////
// Conv1 + Pool1 + Conv2 wires
////////////////////////////////////////////////////////////
wire signed [31:0] conv2_out;
wire conv2_valid_out;

wire conv1_pool1_conv2_busy;
wire conv1_pool1_conv2_done;

wire dbg_pool_valid;
wire [4:0] dbg_pool_row;
wire [4:0] dbg_pool_col;
wire [5:0] dbg_pool_ch;
wire signed [31:0] dbg_pool_out;

wire [4:0] conv2_row_w;
wire [4:0] conv2_col_w;
wire [4:0] conv2_in_ch_w;
wire conv2_win_valid_w;

////////////////////////////////////////////////////////////
// Conv2 output channel counter
// conv2_top outputs out_ch 0~63 for each row,col
////////////////////////////////////////////////////////////
reg [5:0] conv2_ch_cnt;
reg [4:0] conv2_row_reg;
reg [4:0] conv2_col_reg;
reg [5:0] conv2_ch_reg;

////////////////////////////////////////////////////////////
// Pool2 count
////////////////////////////////////////////////////////////
reg [13:0] pool2_count;

parameter POOL2_TOTAL = 14'd12544; // 14*14*64

////////////////////////////////////////////////////////////
// Debug assign
////////////////////////////////////////////////////////////
assign dbg_conv2_out   = conv2_out;
assign dbg_conv2_valid = conv2_valid_out;
assign dbg_conv2_row   = conv2_row_w;
assign dbg_conv2_col   = conv2_col_w;
assign dbg_conv2_ch    = conv2_ch_cnt;

assign busy = conv1_pool1_conv2_busy;

////////////////////////////////////////////////////////////
// Verified Conv1 + Pool1 + Conv2 top
////////////////////////////////////////////////////////////
conv1_pool1_conv2_top u_conv1_pool1_conv2_top (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start),

    .conv2_out(conv2_out),
    .conv2_valid_out(conv2_valid_out),

    .busy(conv1_pool1_conv2_busy),
    .done(conv1_pool1_conv2_done),

    .dbg_pool_valid(dbg_pool_valid),
    .dbg_pool_row(dbg_pool_row),
    .dbg_pool_col(dbg_pool_col),
    .dbg_pool_ch(dbg_pool_ch),
    .dbg_pool_out(dbg_pool_out),

    .dbg_conv2_row(conv2_row_w),
    .dbg_conv2_col(conv2_col_w),
    .dbg_conv2_in_ch(conv2_in_ch_w),
    .dbg_conv2_win_valid(conv2_win_valid_w)
);

////////////////////////////////////////////////////////////
// Conv2 stream metadata
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
// Conv2 output channel counter
// conv2_top outputs out_ch 0~63 for each row,col
//
// NOTE:
// conv2_valid_out / conv2_out are direct outputs from conv2_top.
// For debug metadata, do not register row/col/ch again.
// Use conv2_row_w, conv2_col_w, conv2_ch_cnt directly.
// conv2_ch_cnt is still used by maxpool2_stream.
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        conv2_ch_cnt <= 6'd0;
        conv2_row_reg <= 5'd0;
        conv2_col_reg <= 5'd0;
        conv2_ch_reg  <= 6'd0;
    end
    else begin
        if (start) begin
            conv2_ch_cnt <= 6'd0;
            conv2_row_reg <= 5'd0;
            conv2_col_reg <= 5'd0;
            conv2_ch_reg  <= 6'd0;
        end
        else if (conv2_valid_out) begin
            conv2_row_reg <= conv2_row_w;
            conv2_col_reg <= conv2_col_w;
            conv2_ch_reg  <= conv2_ch_cnt;

            if (conv2_ch_cnt == 6'd63) begin
                conv2_ch_cnt <= 6'd0;
            end
            else begin
                conv2_ch_cnt <= conv2_ch_cnt + 6'd1;
            end
        end
    end
end

////////////////////////////////////////////////////////////
// Pool2 stream
////////////////////////////////////////////////////////////
maxpool2_stream u_pool2 (
    .clk(clk),
    .rst(rst),

    .valid_in(conv2_valid_out),
    .in_data(conv2_out),
    .in_row(conv2_row_w),
    .in_col(conv2_col_w),
    .in_ch(conv2_ch_cnt),

    .valid_out(pool2_valid),
    .out_data(pool2_out),
    .out_row(pool2_row),
    .out_col(pool2_col),
    .out_ch(pool2_ch)
);

////////////////////////////////////////////////////////////
// done control
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
// done control
// done must be generated after the last Pool2 output,
// not just after Conv2 core completion.
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pool2_count <= 14'd0;
        done <= 1'b0;
    end
    else begin
        done <= 1'b0;

        if (start) begin
            pool2_count <= 14'd0;
        end
        else if (pool2_valid) begin
            if (pool2_count == POOL2_TOTAL - 1) begin
                pool2_count <= 14'd0;
                done <= 1'b1;
            end
            else begin
                pool2_count <= pool2_count + 14'd1;
            end
        end
    end
end

endmodule