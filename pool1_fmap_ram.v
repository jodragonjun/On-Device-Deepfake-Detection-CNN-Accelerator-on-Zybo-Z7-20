`timescale 1ns/1ps

module pool1_fmap_ram (
    clk,

    wr_en,
    wr_addr,
    wr_din,

    rd_en,
    rd_addr,
    rd_dout
);

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 15;
parameter DEPTH      = 30752;

input clk;

input wr_en;
input [ADDR_WIDTH-1:0] wr_addr;
input signed [DATA_WIDTH-1:0] wr_din;

input rd_en;
input [ADDR_WIDTH-1:0] rd_addr;
output reg signed [DATA_WIDTH-1:0] rd_dout;

reg signed [DATA_WIDTH-1:0] mem [0:DEPTH-1];

always @(posedge clk) begin
    if (wr_en) begin
        mem[wr_addr] <= wr_din;
    end

    if (rd_en) begin
        rd_dout <= mem[rd_addr];
    end
end

endmodule