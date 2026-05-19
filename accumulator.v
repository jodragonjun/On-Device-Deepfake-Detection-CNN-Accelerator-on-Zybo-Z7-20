module accumulator (
    input clk,
    input rst,
    input acc_rst,
    input valid_in,

    input signed [31:0] in0,
    input signed [31:0] in1,
    input signed [31:0] in2,
    input signed [31:0] in3,

    output reg signed [31:0] acc,
    output reg valid_out
);

reg [3:0] mac_count;

wire signed [31:0] sum_in;
wire signed [31:0] acc_next;

assign sum_in   = in0 + in1 + in2 + in3;
assign acc_next = acc + sum_in;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        acc       <= 32'sd0;
        mac_count <= 4'd0;
        valid_out <= 1'b0;
    end else begin
        valid_out <= 1'b0;

        if (acc_rst) begin
            acc       <= 32'sd0;
            mac_count <= 4'd0;
            valid_out <= 1'b0;
        end else begin
            if (valid_in) begin
                acc <= acc_next;

                if (mac_count == 4'd8) begin
                    mac_count <= 4'd0;
                    valid_out <= 1'b1;
                end else begin
                    mac_count <= mac_count + 4'd1;
                end
            end
        end
    end
end

endmodule