`timescale 1ns/1ps

module conv3_pool2_top (
    clk,
    rst,
    start,

    pool2_wr_en,
    pool2_wr_addr,
    pool2_wr_data,

    conv3_out,
    conv3_valid_out,
    conv3_done,
    conv3_busy,

    conv3_out_row,
    conv3_out_col,
    conv3_out_ch
);

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 14;

input clk;
input rst;
input start;

input pool2_wr_en;
input [ADDR_WIDTH-1:0] pool2_wr_addr;
input signed [DATA_WIDTH-1:0] pool2_wr_data;

output signed [31:0] conv3_out;
output conv3_valid_out;
output reg conv3_done;
output reg conv3_busy;

output [3:0] conv3_out_row;
output [3:0] conv3_out_col;
output [6:0] conv3_out_ch;

reg [2:0] state;

parameter S_IDLE         = 3'd0;
parameter S_START_READER = 3'd1;
parameter S_RUN_WINDOW   = 3'd2;
parameter S_NEXT_POS     = 3'd3;
parameter S_DONE         = 3'd4;

reg reader_start;

reg [3:0] curr_row;   // 0~11
reg [3:0] curr_col;   // 0~11

wire pool2_rd_en;
wire [ADDR_WIDTH-1:0] pool2_rd_addr;
wire signed [DATA_WIDTH-1:0] pool2_rd_data;

wire reader_done;
wire reader_busy;
wire win_valid;
wire last_in_ch;

wire [3:0] reader_out_row;
wire [3:0] reader_out_col;
wire [5:0] reader_in_ch;

wire signed [31:0] p0;
wire signed [31:0] p1;
wire signed [31:0] p2;
wire signed [31:0] p3;
wire signed [31:0] p4;
wire signed [31:0] p5;
wire signed [31:0] p6;
wire signed [31:0] p7;
wire signed [31:0] p8;

wire serializer_busy;

wire conv3_core_start;
wire conv3_core_valid_in;
wire signed [31:0] conv3_core_in_data;
wire [5:0] conv3_core_in_ch;
wire [3:0] conv3_core_k_idx;
wire conv3_core_done;

reg [6:0] conv3_ch_cnt;

assign conv3_out_row = curr_row;
assign conv3_out_col = curr_col;
assign conv3_out_ch  = conv3_ch_cnt;

pool2_fmap_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DEPTH(12544)
) u_pool2_fmap_ram (
    .clk(clk),

    .wr_en(pool2_wr_en),
    .wr_addr(pool2_wr_addr),
    .wr_din(pool2_wr_data),

    .rd_en(pool2_rd_en),
    .rd_addr(pool2_rd_addr),
    .rd_dout(pool2_rd_data)
);

pool2_window_reader #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) u_pool2_window_reader (
    .clk(clk),
    .rst(rst),
    .start(reader_start),

    .req_row(curr_row),
    .req_col(curr_col),

    .mem_dout(pool2_rd_data),
    .mem_addr(pool2_rd_addr),
    .mem_rd_en(pool2_rd_en),

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

conv3_window_serializer u_conv3_window_serializer (
    .clk(clk),
    .rst(rst),

    .win_valid(win_valid),
    .win_in_ch(reader_in_ch),

    .p0(p0), .p1(p1), .p2(p2),
    .p3(p3), .p4(p4), .p5(p5),
    .p6(p6), .p7(p7), .p8(p8),

    .conv3_start(conv3_core_start),
    .conv3_valid_in(conv3_core_valid_in),
    .conv3_in_data(conv3_core_in_data),
    .conv3_in_ch(conv3_core_in_ch),
    .conv3_k_idx(conv3_core_k_idx),

    .busy(serializer_busy)
);

conv3_top u_conv3_top (
    .clk(clk),
    .rst(rst),
    .start(conv3_core_start),

    .valid_in(conv3_core_valid_in),
    .in_data(conv3_core_in_data),
    .in_ch(conv3_core_in_ch),
    .k_idx(conv3_core_k_idx),

    .out(conv3_out),
    .valid_out(conv3_valid_out),
    .done(conv3_core_done)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        conv3_ch_cnt <= 7'd0;
    end
    else begin
        if (reader_start) begin
            conv3_ch_cnt <= 7'd0;
        end
        else if (conv3_valid_out) begin
            if (conv3_ch_cnt == 7'd127) begin
                conv3_ch_cnt <= 7'd0;
            end
            else begin
                conv3_ch_cnt <= conv3_ch_cnt + 7'd1;
            end
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state        <= S_IDLE;
        reader_start <= 1'b0;

        curr_row     <= 4'd0;
        curr_col     <= 4'd0;

        conv3_done   <= 1'b0;
        conv3_busy   <= 1'b0;
    end
    else begin
        reader_start <= 1'b0;
        conv3_done   <= 1'b0;

        case (state)

            S_IDLE: begin
                conv3_busy <= 1'b0;
                curr_row   <= 4'd0;
                curr_col   <= 4'd0;

                if (start) begin
                    conv3_busy <= 1'b1;
                    state      <= S_START_READER;
                end
            end

            S_START_READER: begin
                conv3_busy   <= 1'b1;
                reader_start <= 1'b1;
                state        <= S_RUN_WINDOW;
            end

            S_RUN_WINDOW: begin
                conv3_busy <= 1'b1;

                if (conv3_core_done) begin
                    state <= S_NEXT_POS;
                end
            end

            S_NEXT_POS: begin
                if ((curr_row == 4'd11) && (curr_col == 4'd11)) begin
                    state <= S_DONE;
                end
                else begin
                    if (curr_col == 4'd11) begin
                        curr_col <= 4'd0;
                        curr_row <= curr_row + 4'd1;
                    end
                    else begin
                        curr_col <= curr_col + 4'd1;
                    end

                    state <= S_START_READER;
                end
            end

            S_DONE: begin
                conv3_busy <= 1'b0;
                conv3_done <= 1'b1;
                state      <= S_IDLE;
            end

            default: begin
                state <= S_IDLE;
            end

        endcase
    end
end

endmodule