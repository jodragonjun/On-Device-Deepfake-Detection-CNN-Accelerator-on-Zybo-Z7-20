`timescale 1ns/1ps

module weight_rom_conv3_b0 (
    clk,
    addr,
    data
);

input clk;
input [14:0] addr;
output reg signed [15:0] data;

parameter DEPTH = 18432;

(* rom_style = "block" *) reg signed [15:0] mem [0:DEPTH-1];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv3_weight_b0.hex", mem);
end

always @(posedge clk) begin
    data <= mem[addr];
end

endmodule


module weight_rom_conv3_b1 (
    clk,
    addr,
    data
);

input clk;
input [14:0] addr;
output reg signed [15:0] data;

parameter DEPTH = 18432;

(* rom_style = "block" *) reg signed [15:0] mem [0:DEPTH-1];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv3_weight_b1.hex", mem);
end

always @(posedge clk) begin
    data <= mem[addr];
end

endmodule


module weight_rom_conv3_b2 (
    clk,
    addr,
    data
);

input clk;
input [14:0] addr;
output reg signed [15:0] data;

parameter DEPTH = 18432;

(* rom_style = "block" *) reg signed [15:0] mem [0:DEPTH-1];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv3_weight_b2.hex", mem);
end

always @(posedge clk) begin
    data <= mem[addr];
end

endmodule


module weight_rom_conv3_b3 (
    clk,
    addr,
    data
);

input clk;
input [14:0] addr;
output reg signed [15:0] data;

parameter DEPTH = 18432;

(* rom_style = "block" *) reg signed [15:0] mem [0:DEPTH-1];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv3_weight_b3.hex", mem);
end

always @(posedge clk) begin
    data <= mem[addr];
end

endmodule

