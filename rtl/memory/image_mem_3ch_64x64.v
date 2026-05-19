module image_mem_3ch_64x64 (
    clk,
    rst,

    wr_en,
    wr_addr,
    wr_r,
    wr_g,
    wr_b,

    rd_en,
    rd_addr,

    rd_r,
    rd_g,
    rd_b,
    rd_valid
);

input clk;
input rst;

input wr_en;
input [11:0] wr_addr;
input signed [15:0] wr_r;
input signed [15:0] wr_g;
input signed [15:0] wr_b;

input rd_en;
input [11:0] rd_addr;

output reg signed [15:0] rd_r;
output reg signed [15:0] rd_g;
output reg signed [15:0] rd_b;
output reg rd_valid;

parameter IMG_SIZE = 4096;

/*
    IMPORTANT:
    - Do not reset memory arrays.
    - If memory arrays are reset, Vivado cannot infer BRAM properly.
    - Only output registers and valid signal are reset.
*/
(* ram_style = "block" *) reg signed [15:0] mem_r [0:4095];
(* ram_style = "block" *) reg signed [15:0] mem_g [0:4095];
(* ram_style = "block" *) reg signed [15:0] mem_b [0:4095];

always @(posedge clk) begin
    if (wr_en) begin
        mem_r[wr_addr] <= wr_r;
        mem_g[wr_addr] <= wr_g;
        mem_b[wr_addr] <= wr_b;
    end
end

always @(posedge clk) begin
    if (rst) begin
        rd_r     <= 16'sd0;
        rd_g     <= 16'sd0;
        rd_b     <= 16'sd0;
        rd_valid <= 1'b0;
    end
    else begin
        rd_valid <= rd_en;

        if (rd_en) begin
            rd_r <= mem_r[rd_addr];
            rd_g <= mem_g[rd_addr];
            rd_b <= mem_b[rd_addr];
        end
    end
end

endmodule