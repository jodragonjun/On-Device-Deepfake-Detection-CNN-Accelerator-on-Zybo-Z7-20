`timescale 1ns/1ps

module maxpool1_stream (
    clk,
    rst,
    valid_in,
    in_data,
    in_row,
    in_col,
    in_ch,
    valid_out,
    out_data,
    out_row,
    out_col,
    out_ch
);

input clk;
input rst;
input valid_in;

input signed [31:0] in_data;
input [5:0] in_row;   // 0 ~ 61
input [5:0] in_col;   // 0 ~ 61
input [5:0] in_ch;    // 0 ~ 31

output reg valid_out;
output reg signed [31:0] out_data;
output reg [4:0] out_row;  // 0 ~ 30
output reg [4:0] out_col;  // 0 ~ 30
output reg [5:0] out_ch;   // 0 ~ 31

parameter CH_NUM = 32;
parameter POOL_W = 31;

////////////////////////////////////////////////////////////
// Internal buffer
// IMPORTANT:
// - Do not reset these arrays.
// - Do not write these arrays inside async reset always block.
// - These buffers should be inferred as distributed RAM.
////////////////////////////////////////////////////////////
(* ram_style = "distributed" *) reg signed [31:0] left_buf    [0:31];
(* ram_style = "distributed" *) reg signed [31:0] top_row_buf [0:991];

wire [4:0] pool_row;
wire [4:0] pool_col;
wire [9:0] buf_idx;

wire even_row;
wire even_col;

wire signed [31:0] left_value;
wire signed [31:0] top_value;
wire signed [31:0] horizontal_max;
wire signed [31:0] vertical_max;

assign pool_row = in_row[5:1];
assign pool_col = in_col[5:1];

assign even_row = (in_row[0] == 1'b0);
assign even_col = (in_col[0] == 1'b0);

assign buf_idx = {pool_col, in_ch[4:0]};

assign left_value = left_buf[in_ch[4:0]];
assign top_value  = top_row_buf[buf_idx];

assign horizontal_max = (left_value >= in_data) ? left_value : in_data;
assign vertical_max   = (top_value >= horizontal_max) ? top_value : horizontal_max;

////////////////////////////////////////////////////////////
// Buffer write logic
// No reset here.
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (valid_in) begin

        // even column: store left value
        if (even_col) begin
            left_buf[in_ch[4:0]] <= in_data;
        end

        // odd column + even row: store horizontal max
        else if (even_row) begin
            top_row_buf[buf_idx] <= horizontal_max;
        end
    end
end

////////////////////////////////////////////////////////////
// Output logic
// Only output registers are reset.
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_out <= 1'b0;
        out_data  <= 32'sd0;
        out_row   <= 5'd0;
        out_col   <= 5'd0;
        out_ch    <= 6'd0;
    end
    else begin
        valid_out <= 1'b0;

        // odd row + odd column: final 2x2 maxpool output
        if (valid_in && !even_row && !even_col) begin
            valid_out <= 1'b1;
            out_data  <= vertical_max;
            out_row   <= pool_row;
            out_col   <= pool_col;
            out_ch    <= in_ch;
        end
    end
end

endmodule