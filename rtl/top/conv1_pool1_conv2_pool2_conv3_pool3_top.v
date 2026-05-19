`timescale 1ns/1ps

module conv1_pool1_conv2_pool2_conv3_pool3_top (
    clk,
    rst,

    img_wr_en,
    img_wr_addr,
    img_wr_r,
    img_wr_g,
    img_wr_b,

    start,

    pool3_out,
    pool3_valid,
    pool3_row,
    pool3_col,
    pool3_ch,

    busy,
    done,

    dbg_conv3_out,
    dbg_conv3_valid,
    dbg_conv3_row,
    dbg_conv3_col,
    dbg_conv3_ch
);

input clk;
input rst;

input img_wr_en;
input [11:0] img_wr_addr;
input signed [15:0] img_wr_r;
input signed [15:0] img_wr_g;
input signed [15:0] img_wr_b;

input start;

output signed [31:0] pool3_out;
output pool3_valid;
output [2:0] pool3_row;
output [2:0] pool3_col;
output [6:0] pool3_ch;

output busy;
output reg done;

output signed [31:0] dbg_conv3_out;
output dbg_conv3_valid;
output [3:0] dbg_conv3_row;
output [3:0] dbg_conv3_col;
output [6:0] dbg_conv3_ch;

wire signed [31:0] pool2_out;
wire pool2_valid;
wire [3:0] pool2_row;
wire [3:0] pool2_col;
wire [5:0] pool2_ch;

wire base_busy;
wire base_done;

wire signed [31:0] dbg_conv2_out;
wire dbg_conv2_valid;
wire [4:0] dbg_conv2_row;
wire [4:0] dbg_conv2_col;
wire [5:0] dbg_conv2_ch;

wire pool2_wr_en;
wire [13:0] pool2_wr_addr;
wire signed [31:0] pool2_wr_data;

reg base_done_d;
reg conv3_start;

wire signed [31:0] conv3_out;
wire conv3_valid_out;
wire conv3_done;
wire conv3_busy;

wire [3:0] conv3_row_w;
wire [3:0] conv3_col_w;
wire [6:0] conv3_ch_w;

reg [12:0] pool3_count;

parameter POOL3_TOTAL = 13'd4608; // 6*6*128

assign pool2_wr_en   = pool2_valid;
assign pool2_wr_addr = pool2_addr_calc(pool2_ch, pool2_row, pool2_col);
assign pool2_wr_data = pool2_out;

assign busy = base_busy | conv3_busy;

assign dbg_conv3_out   = conv3_out;
assign dbg_conv3_valid = conv3_valid_out;
assign dbg_conv3_row   = conv3_row_w;
assign dbg_conv3_col   = conv3_col_w;
assign dbg_conv3_ch    = conv3_ch_w;

function [13:0] pool2_addr_calc;
    input [5:0] ch;
    input [3:0] row;
    input [3:0] col;

    reg [15:0] ch_base;
    reg [15:0] row_base;
    reg [15:0] temp_addr;

    begin
        // ch * 196 = ch * (128 + 64 + 4)
        ch_base = ({10'd0, ch} << 7) + ({10'd0, ch} << 6) + ({10'd0, ch} << 2);

        // row * 14 = row * (16 - 2)
        row_base = ({12'd0, row} << 4) - ({12'd0, row} << 1);

        temp_addr = ch_base + row_base + {12'd0, col};

        pool2_addr_calc = temp_addr[13:0];
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        base_done_d <= 1'b0;
        conv3_start <= 1'b0;
    end
    else begin
        base_done_d <= base_done;
        conv3_start <= base_done & (~base_done_d);
    end
end

conv1_pool1_conv2_pool2_top u_base (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start),

    .pool2_out(pool2_out),
    .pool2_valid(pool2_valid),
    .pool2_row(pool2_row),
    .pool2_col(pool2_col),
    .pool2_ch(pool2_ch),

    .busy(base_busy),
    .done(base_done),

    .dbg_conv2_out(dbg_conv2_out),
    .dbg_conv2_valid(dbg_conv2_valid),
    .dbg_conv2_row(dbg_conv2_row),
    .dbg_conv2_col(dbg_conv2_col),
    .dbg_conv2_ch(dbg_conv2_ch)
);

conv3_pool2_top u_conv3_pool2_top (
    .clk(clk),
    .rst(rst),
    .start(conv3_start),

    .pool2_wr_en(pool2_wr_en),
    .pool2_wr_addr(pool2_wr_addr),
    .pool2_wr_data(pool2_wr_data),

    .conv3_out(conv3_out),
    .conv3_valid_out(conv3_valid_out),
    .conv3_done(conv3_done),
    .conv3_busy(conv3_busy),

    .conv3_out_row(conv3_row_w),
    .conv3_out_col(conv3_col_w),
    .conv3_out_ch(conv3_ch_w)
);

maxpool3_stream u_pool3 (
    .clk(clk),
    .rst(rst),

    .valid_in(conv3_valid_out),
    .in_data(conv3_out),
    .in_row(conv3_row_w),
    .in_col(conv3_col_w),
    .in_ch(conv3_ch_w),

    .valid_out(pool3_valid),
    .out_data(pool3_out),
    .out_row(pool3_row),
    .out_col(pool3_col),
    .out_ch(pool3_ch)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pool3_count <= 13'd0;
        done        <= 1'b0;
    end
    else begin
        done <= 1'b0;

        if (start) begin
            pool3_count <= 13'd0;
        end

        if (pool3_valid) begin
            if (pool3_count == POOL3_TOTAL - 1) begin
                pool3_count <= 13'd0;
                done        <= 1'b1;
            end
            else begin
                pool3_count <= pool3_count + 13'd1;
            end
        end
    end
end

endmodule