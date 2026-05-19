module weight_rom_conv1 (
    input clk,
    input [9:0] addr,

    output reg signed [15:0] data
);

    reg signed [15:0] mem [0:863];

    initial begin
        $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv1_weight.hex", mem);
    end

    always @(posedge clk) begin
        data <= mem[addr];
    end

endmodule