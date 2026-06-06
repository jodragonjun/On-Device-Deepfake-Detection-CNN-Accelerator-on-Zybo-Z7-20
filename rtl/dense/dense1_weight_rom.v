module dense1_weight_rom (
    clk,
    addr,
    dout
);

input clk;
input [12:0] addr;
output reg signed [15:0] dout;

(* rom_style = "block" *) reg signed [15:0] mem [0:8191];

initial begin
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/dense1_weight.hex", mem);
end

always @(posedge clk) begin
    dout <= mem[addr];
end

endmodule