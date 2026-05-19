`timescale 1ns/1ps

module conv1_pool1_conv2_top (
    clk,
    rst,

    img_wr_en,
    img_wr_addr,
    img_wr_r,
    img_wr_g,
    img_wr_b,

    start,

    conv2_out,
    conv2_valid_out,

    busy,
    done,

    dbg_pool_valid,
    dbg_pool_row,
    dbg_pool_col,
    dbg_pool_ch,
    dbg_pool_out,

    dbg_conv2_row,
    dbg_conv2_col,
    dbg_conv2_in_ch,
    dbg_conv2_win_valid
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

output signed [31:0] conv2_out;
output conv2_valid_out;

output busy;
output done;

output dbg_pool_valid;
output [4:0] dbg_pool_row;
output [4:0] dbg_pool_col;
output [5:0] dbg_pool_ch;
output signed [31:0] dbg_pool_out;

output [4:0] dbg_conv2_row;
output [4:0] dbg_conv2_col;
output [4:0] dbg_conv2_in_ch;
output dbg_conv2_win_valid;

////////////////////////////////////////////////////////////
// Conv1 + Pool1 wires
////////////////////////////////////////////////////////////
wire conv1_pool1_busy;
wire conv1_pool1_done;

wire signed [31:0] pool_out;
wire pool_valid;
wire [4:0] pool_row;
wire [4:0] pool_col;
wire [5:0] pool_ch;

////////////////////////////////////////////////////////////
// Pool1 RAM write wires for Conv2
////////////////////////////////////////////////////////////
wire pool1_wr_en;
wire [14:0] pool1_wr_addr;
wire signed [31:0] pool1_wr_data;

////////////////////////////////////////////////////////////
// Conv2 control wires
////////////////////////////////////////////////////////////
reg conv1_pool1_done_d;
reg conv2_start;

wire conv2_done;
wire conv2_busy;

////////////////////////////////////////////////////////////
// Function: Pool1 memory address
// addr = ch * 31 * 31 + row * 31 + col
////////////////////////////////////////////////////////////
function [14:0] pool1_addr_calc;
    input [4:0] ch;
    input [4:0] row;
    input [4:0] col;

    reg [15:0] ch_base;
    reg [15:0] row_base;
    reg [15:0] temp_addr;

    begin
        // ch * 961 = ch * (1024 - 64 + 1)
        ch_base  = ({11'd0, ch} << 10) - ({11'd0, ch} << 6) + {11'd0, ch};

        // row * 31 = row * (32 - 1)
        row_base = ({11'd0, row} << 5) - {11'd0, row};

        temp_addr = ch_base + row_base + {11'd0, col};

        pool1_addr_calc = temp_addr[14:0];
    end
endfunction

////////////////////////////////////////////////////////////
// Pool1 stream -> Conv2 Pool1 RAM write
////////////////////////////////////////////////////////////
assign pool1_wr_en   = pool_valid;
assign pool1_wr_addr = pool1_addr_calc(pool_ch[4:0], pool_row, pool_col);
assign pool1_wr_data = pool_out;

////////////////////////////////////////////////////////////
// Top status
////////////////////////////////////////////////////////////
assign busy = conv1_pool1_busy | conv2_busy;
assign done = conv2_done;

////////////////////////////////////////////////////////////
// Debug assign
////////////////////////////////////////////////////////////
assign dbg_pool_valid = pool_valid;
assign dbg_pool_row   = pool_row;
assign dbg_pool_col   = pool_col;
assign dbg_pool_ch    = pool_ch;
assign dbg_pool_out   = pool_out;

////////////////////////////////////////////////////////////
// Conv2 start generation
// Conv2 starts after all Pool1 outputs are stored.
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        conv1_pool1_done_d <= 1'b0;
        conv2_start        <= 1'b0;
    end
    else begin
        conv1_pool1_done_d <= conv1_pool1_done;

        conv2_start <= conv1_pool1_done & (~conv1_pool1_done_d);
    end
end

////////////////////////////////////////////////////////////
// Conv1 + Pool1 verified block
////////////////////////////////////////////////////////////
conv1_pool1_top u_conv1_pool1_top (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start),

    .busy(conv1_pool1_busy),
    .done(conv1_pool1_done),

    .pool_out(pool_out),
    .pool_valid(pool_valid),
    .pool_row(pool_row),
    .pool_col(pool_col),
    .pool_ch(pool_ch)
);

////////////////////////////////////////////////////////////
// Conv2 from Pool1 feature map
////////////////////////////////////////////////////////////
conv2_pool1_top #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(15)
) u_conv2_pool1_top (
    .clk(clk),
    .rst(rst),
    .start(conv2_start),

    .pool1_wr_en(pool1_wr_en),
    .pool1_wr_addr(pool1_wr_addr),
    .pool1_wr_data(pool1_wr_data),

    .conv2_out(conv2_out),
    .conv2_valid_out(conv2_valid_out),
    .conv2_done(conv2_done),
    .conv2_busy(conv2_busy),

    .dbg_out_row(dbg_conv2_row),
    .dbg_out_col(dbg_conv2_col),
    .dbg_in_ch(dbg_conv2_in_ch),
    .dbg_win_valid(dbg_conv2_win_valid),

    .dbg_p0(),
    .dbg_p1(),
    .dbg_p2(),
    .dbg_p3(),
    .dbg_p4(),
    .dbg_p5(),
    .dbg_p6(),
    .dbg_p7(),
    .dbg_p8()
);

endmodule