module weight_rom_conv2 (
    input clk,
    input [14:0] addr,
    output reg signed [15:0] data
);

reg signed [15:0] mem [0:18431];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv2_weight.hex", mem);
end

always @(posedge clk) begin
    data <= mem[addr];
end

endmodule