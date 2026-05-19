module dense1_bias_rom (
    clk,
    addr,
    dout
);

input clk;
input [5:0] addr;
output reg signed [95:0] dout;

reg [15:0] mem [0:63];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/dense1_bias.hex", mem);
end

always @(posedge clk) begin
    dout <= {{80{mem[addr][15]}}, mem[addr]};
end

endmodule