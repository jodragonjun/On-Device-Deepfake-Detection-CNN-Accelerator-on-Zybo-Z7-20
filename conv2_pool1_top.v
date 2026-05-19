`timescale 1ns/1ps

module conv2_pool1_top (
    clk,
    rst,
    start,

    pool1_wr_en,
    pool1_wr_addr,
    pool1_wr_data,

    conv2_out,
    conv2_valid_out,
    conv2_done,
    conv2_busy,

    dbg_out_row,
    dbg_out_col,
    dbg_in_ch,
    dbg_win_valid,

    dbg_p0, dbg_p1, dbg_p2,
    dbg_p3, dbg_p4, dbg_p5,
    dbg_p6, dbg_p7, dbg_p8
);

////////////////////////////////////////////////////////////
// Parameter
////////////////////////////////////////////////////////////
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 15;

////////////////////////////////////////////////////////////
// Port
////////////////////////////////////////////////////////////
input clk;
input rst;
input start;

input pool1_wr_en;
input [ADDR_WIDTH-1:0] pool1_wr_addr;
input signed [DATA_WIDTH-1:0] pool1_wr_data;

output signed [31:0] conv2_out;
output conv2_valid_out;
output reg conv2_done;
output reg conv2_busy;

output [4:0] dbg_out_row;
output [4:0] dbg_out_col;
output [4:0] dbg_in_ch;
output dbg_win_valid;

output signed [DATA_WIDTH-1:0] dbg_p0;
output signed [DATA_WIDTH-1:0] dbg_p1;
output signed [DATA_WIDTH-1:0] dbg_p2;
output signed [DATA_WIDTH-1:0] dbg_p3;
output signed [DATA_WIDTH-1:0] dbg_p4;
output signed [DATA_WIDTH-1:0] dbg_p5;
output signed [DATA_WIDTH-1:0] dbg_p6;
output signed [DATA_WIDTH-1:0] dbg_p7;
output signed [DATA_WIDTH-1:0] dbg_p8;

////////////////////////////////////////////////////////////
// FSM state
////////////////////////////////////////////////////////////
reg [2:0] state;

parameter S_IDLE         = 3'd0;
parameter S_START_READER = 3'd1;
parameter S_RUN_WINDOW   = 3'd2;
parameter S_NEXT_POS     = 3'd3;
parameter S_DONE         = 3'd4;

////////////////////////////////////////////////////////////
// Position control
////////////////////////////////////////////////////////////
reg reader_start;

reg [4:0] curr_row;   // 0 ~ 28
reg [4:0] curr_col;   // 0 ~ 28

////////////////////////////////////////////////////////////
// Pool1 RAM read wires
////////////////////////////////////////////////////////////
wire pool1_rd_en;
wire [ADDR_WIDTH-1:0] pool1_rd_addr;
wire signed [DATA_WIDTH-1:0] pool1_rd_data;

////////////////////////////////////////////////////////////
// Window reader wires
////////////////////////////////////////////////////////////
wire reader_done;
wire reader_busy;

wire win_valid;
wire last_in_ch;

wire [4:0] reader_out_row;
wire [4:0] reader_out_col;
wire [4:0] reader_in_ch;

wire signed [DATA_WIDTH-1:0] p0;
wire signed [DATA_WIDTH-1:0] p1;
wire signed [DATA_WIDTH-1:0] p2;
wire signed [DATA_WIDTH-1:0] p3;
wire signed [DATA_WIDTH-1:0] p4;
wire signed [DATA_WIDTH-1:0] p5;
wire signed [DATA_WIDTH-1:0] p6;
wire signed [DATA_WIDTH-1:0] p7;
wire signed [DATA_WIDTH-1:0] p8;

////////////////////////////////////////////////////////////
// Serializer wires
////////////////////////////////////////////////////////////
wire serializer_busy;

wire conv2_core_start;
wire conv2_core_valid_in;
wire signed [31:0] conv2_core_in_data;
wire [5:0] conv2_core_in_ch;
wire [3:0] conv2_core_k_idx;

////////////////////////////////////////////////////////////
// Conv2 core wires
////////////////////////////////////////////////////////////
wire conv2_core_done;

////////////////////////////////////////////////////////////
// Debug assign
////////////////////////////////////////////////////////////
assign dbg_out_row   = curr_row;
assign dbg_out_col   = curr_col;
assign dbg_in_ch     = reader_in_ch;
assign dbg_win_valid = win_valid;

assign dbg_p0 = p0;
assign dbg_p1 = p1;
assign dbg_p2 = p2;
assign dbg_p3 = p3;
assign dbg_p4 = p4;
assign dbg_p5 = p5;
assign dbg_p6 = p6;
assign dbg_p7 = p7;
assign dbg_p8 = p8;

////////////////////////////////////////////////////////////
// Pool1 feature map RAM
// write : conv1_pool1_top stream
// read  : conv2 window reader
////////////////////////////////////////////////////////////
pool1_fmap_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DEPTH(30752)
) u_pool1_fmap_ram (
    .clk(clk),

    .wr_en(pool1_wr_en),
    .wr_addr(pool1_wr_addr),
    .wr_din(pool1_wr_data),

    .rd_en(pool1_rd_en),
    .rd_addr(pool1_rd_addr),
    .rd_dout(pool1_rd_data)
);

////////////////////////////////////////////////////////////
// Pool1 3x3 window reader
////////////////////////////////////////////////////////////
pool1_window_reader #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_pool1_window_reader (
    .clk(clk),
    .rst(rst),
    .start(reader_start),

    .req_row(curr_row),
    .req_col(curr_col),

    .mem_dout(pool1_rd_data),
    .mem_addr(pool1_rd_addr),
    .mem_rd_en(pool1_rd_en),

    .valid_out(win_valid),
    .done(reader_done),
    .busy(reader_busy),

    .out_row(reader_out_row),
    .out_col(reader_out_col),
    .in_ch(reader_in_ch),

    .p0(p0), .p1(p1), .p2(p2),
    .p3(p3), .p4(p4), .p5(p5),
    .p6(p6), .p7(p7), .p8(p8),

    .last_in_ch(last_in_ch)
);

////////////////////////////////////////////////////////////
// 3x3 window serializer
// p0~p8 -> in_data, k_idx
////////////////////////////////////////////////////////////
conv2_window_serializer u_conv2_window_serializer (
    .clk(clk),
    .rst(rst),

    .win_valid(win_valid),
    .win_in_ch(reader_in_ch),

    .p0(p0), .p1(p1), .p2(p2),
    .p3(p3), .p4(p4), .p5(p5),
    .p6(p6), .p7(p7), .p8(p8),

    .conv2_start(conv2_core_start),
    .conv2_valid_in(conv2_core_valid_in),
    .conv2_in_data(conv2_core_in_data),
    .conv2_in_ch(conv2_core_in_ch),
    .conv2_k_idx(conv2_core_k_idx),

    .busy(serializer_busy)
);

////////////////////////////////////////////////////////////
// Verified Conv2 top
////////////////////////////////////////////////////////////
conv2_top u_conv2_top (
    .clk(clk),
    .rst(rst),
    .start(conv2_core_start),

    .valid_in(conv2_core_valid_in),
    .in_data(conv2_core_in_data),
    .in_ch(conv2_core_in_ch),
    .k_idx(conv2_core_k_idx),

    .out(conv2_out),
    .valid_out(conv2_valid_out),
    .done(conv2_core_done)
);

////////////////////////////////////////////////////////////
// Conv2 Pool1 position controller
//
// output position order:
// row 0 col 0
// row 0 col 1
// ...
// row 28 col 28
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state        <= S_IDLE;
        reader_start <= 1'b0;

        curr_row     <= 5'd0;
        curr_col     <= 5'd0;

        conv2_done   <= 1'b0;
        conv2_busy   <= 1'b0;
    end
    else begin
        reader_start <= 1'b0;
        conv2_done   <= 1'b0;

        case (state)

            S_IDLE: begin
                conv2_busy <= 1'b0;
                curr_row   <= 5'd0;
                curr_col   <= 5'd0;

                if (start) begin
                    conv2_busy <= 1'b1;
                    state      <= S_START_READER;
                end
            end

            S_START_READER: begin
                conv2_busy   <= 1'b1;
                reader_start <= 1'b1;
                state        <= S_RUN_WINDOW;
            end

            S_RUN_WINDOW: begin
                conv2_busy <= 1'b1;

                if (conv2_core_done) begin
                    state <= S_NEXT_POS;
                end
            end

            S_NEXT_POS: begin
                if ((curr_row == 5'd28) && (curr_col == 5'd28)) begin
                    state <= S_DONE;
                end
                else begin
                    if (curr_col == 5'd28) begin
                        curr_col <= 5'd0;
                        curr_row <= curr_row + 5'd1;
                    end
                    else begin
                        curr_col <= curr_col + 5'd1;
                    end

                    state <= S_START_READER;
                end
            end

            S_DONE: begin
                conv2_busy <= 1'b0;
                conv2_done <= 1'b1;
                state      <= S_IDLE;
            end

            default: begin
                state <= S_IDLE;
            end

        endcase
    end
end

endmodule