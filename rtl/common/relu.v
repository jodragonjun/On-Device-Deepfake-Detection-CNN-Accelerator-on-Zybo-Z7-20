module relu (
    input clk,
    input rst,
    input valid_in,
    input signed [31:0] in,

    output reg signed [31:0] out,
    output reg valid_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out <= 0;
            valid_out <= 0;
        end
        else begin
            valid_out <= valid_in;

            if (valid_in) begin
                if (in[31] == 1'b1)
                    out <= 0;
                else
                    out <= in;
            end
        end
    end

endmodule