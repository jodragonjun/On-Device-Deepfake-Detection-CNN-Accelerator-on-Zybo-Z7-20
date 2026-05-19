`timescale 1ns/1ps

module addr_gen_conv1 (
    input [5:0] out_ch,
    input [1:0] in_ch,
    input [3:0] k_idx,

    output [9:0] addr
);

////////////////////////////////////////////////////////////
// weight layout
// addr = out_ch * 27 + in_ch * 9 + k_idx
//
// out_ch : 0~31
// in_ch  : 0~2
// k_idx  : 0, 4, 8
//
// max addr = 31*27 + 2*9 + 8 = 863
////////////////////////////////////////////////////////////

wire [9:0] out_ch_ext;
wire [9:0] in_ch_ext;
wire [9:0] k_idx_ext;

wire [9:0] base_out;
wire [9:0] base_in;

assign out_ch_ext = {4'd0, out_ch};
assign in_ch_ext  = {8'd0, in_ch};
assign k_idx_ext  = {6'd0, k_idx};

// out_ch * 27 = out_ch * (32 - 4 - 1)
assign base_out = (out_ch_ext << 5) - (out_ch_ext << 2) - out_ch_ext;

// in_ch * 9 = in_ch * (8 + 1)
assign base_in = (in_ch_ext << 3) + in_ch_ext;

assign addr = base_out + base_in + k_idx_ext;

endmodule