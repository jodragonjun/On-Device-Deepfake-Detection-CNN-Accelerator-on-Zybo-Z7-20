module pe (
    input clk,
    input rst,
    input valid_in,

    input signed [15:0] a,
    input signed [15:0] b,

    output reg signed [31:0] out,
    output reg valid_out
);

    reg signed [31:0] mult;
    reg valid_d1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mult <= 32'sd0;
            out <= 32'sd0;
            valid_d1 <= 1'b0;
            valid_out <= 1'b0;
        end
        else begin
            mult <= a * b;
            out <= mult >>> 8;
            valid_d1 <= valid_in;
            valid_out <= valid_d1;
        end
    end

endmodule