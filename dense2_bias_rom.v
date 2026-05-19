module dense2_bias_rom (
    clk,
    dout
);

input clk;
output reg signed [95:0] dout;

reg [15:0] mem [0:0];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/dense2_bias.hex", mem);
end
always @(posedge clk) begin
    dout <= {{80{mem[0][15]}}, mem[0]};
end

endmodule