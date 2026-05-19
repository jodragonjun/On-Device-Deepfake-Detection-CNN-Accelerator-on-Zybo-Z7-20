`timescale 1ns/1ps

module bias_rom_conv3 (
    clk,
    addr,
    data
);

input clk;
input [6:0] addr;
output reg signed [15:0] data;

parameter DEPTH = 128;

(* rom_style = "distributed" *) reg signed [15:0] mem [0:DEPTH-1];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv3_bias.hex", mem);
end

always @(posedge clk) begin
    data <= mem[addr];
end

endmodule