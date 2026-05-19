module dense2_weight_rom (
    clk,
    addr,
    dout
);

input clk;
input [5:0] addr;
output reg signed [15:0] dout;

(* rom_style = "block" *) reg signed [15:0] mem [0:63];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/dense2_weight.hex", mem);
end

always @(posedge clk) begin
    dout <= mem[addr];
end

endmodule