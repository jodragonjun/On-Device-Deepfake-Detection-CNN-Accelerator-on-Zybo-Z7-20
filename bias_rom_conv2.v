module bias_rom_conv2 (
    input clk,
    input [5:0] addr,
    output reg signed [15:0] data
);

reg signed [15:0] mem [0:63];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv2_bias.hex", mem);
end

always @(posedge clk) begin
    data <= mem[addr];
end

endmodule