module bias_rom_conv1 (
    input clk,
    input [5:0] addr,
    output reg signed [15:0] data
);

reg signed [15:0] mem [0:31];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv1_bias.hex", mem);
end

always @(posedge clk) begin
    data <= mem[addr];
end

endmodule