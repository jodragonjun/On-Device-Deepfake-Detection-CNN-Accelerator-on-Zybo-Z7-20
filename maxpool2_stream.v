`timescale 1ns/1ps

module maxpool2_stream (
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
input [4:0] in_row;     // 0 ~ 28
input [4:0] in_col;     // 0 ~ 28
input [5:0] in_ch;      // 0 ~ 63

output reg valid_out;
output reg signed [31:0] out_data;
output reg [3:0] out_row;   // 0 ~ 13
output reg [3:0] out_col;   // 0 ~ 13
output reg [5:0] out_ch;    // 0 ~ 63

////////////////////////////////////////////////////////////
// Internal buffer
// IMPORTANT:
// - Do not reset these arrays.
// - Resetting arrays causes FF explosion.
// - These buffers should be inferred as distributed RAM.
////////////////////////////////////////////////////////////
(* ram_style = "distributed" *) reg signed [31:0] top_left     [0:63];
(* ram_style = "distributed" *) reg signed [31:0] bottom_left  [0:63];
(* ram_style = "distributed" *) reg signed [31:0] top_pair_max [0:895];

wire [3:0] pool_col_idx;
wire [3:0] pool_row_idx;
wire [9:0] top_pair_addr;

wire valid_region;
wire even_row;
wire even_col;

wire signed [31:0] top_left_value;
wire signed [31:0] bottom_left_value;
wire signed [31:0] top_pair_value;

wire signed [31:0] top_pair_write_data;
wire signed [31:0] bottom_pair_max;
wire signed [31:0] final_max;

assign pool_row_idx  = in_row[4:1];
assign pool_col_idx  = in_col[4:1];

assign top_pair_addr = {pool_col_idx, 6'b000000} + {4'b0000, in_ch};

assign valid_region = (in_row <= 5'd27) && (in_col <= 5'd27);

assign even_row = (in_row[0] == 1'b0);
assign even_col = (in_col[0] == 1'b0);

assign top_left_value    = top_left[in_ch];
assign bottom_left_value = bottom_left[in_ch];
assign top_pair_value    = top_pair_max[top_pair_addr];

assign top_pair_write_data = (top_left_value > in_data) ? top_left_value : in_data;
assign bottom_pair_max     = (bottom_left_value > in_data) ? bottom_left_value : in_data;
assign final_max           = (top_pair_value > bottom_pair_max) ? top_pair_value : bottom_pair_max;

////////////////////////////////////////////////////////////
// Buffer write logic
// No reset here.
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (valid_in && valid_region) begin

        // even row, even col: top-left
        if (even_row && even_col) begin
            top_left[in_ch] <= in_data;
        end

        // even row, odd col: top pair max
        else if (even_row && !even_col) begin
            top_pair_max[top_pair_addr] <= top_pair_write_data;
        end

        // odd row, even col: bottom-left
        else if (!even_row && even_col) begin
            bottom_left[in_ch] <= in_data;
        end
    end
end

////////////////////////////////////////////////////////////
// Output logic
// Only output registers are reset.
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (rst) begin
        valid_out <= 1'b0;
        out_data  <= 32'sd0;
        out_row   <= 4'd0;
        out_col   <= 4'd0;
        out_ch    <= 6'd0;
    end
    else begin
        valid_out <= 1'b0;

        // odd row, odd col: final 2x2 maxpool output
        if (valid_in && valid_region && !even_row && !even_col) begin
            valid_out <= 1'b1;
            out_data  <= final_max;
            out_row   <= pool_row_idx;
            out_col   <= pool_col_idx;
            out_ch    <= in_ch;
        end
    end
end

endmodule