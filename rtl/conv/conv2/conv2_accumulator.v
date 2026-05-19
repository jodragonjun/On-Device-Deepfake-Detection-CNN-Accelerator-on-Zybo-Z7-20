module conv2_accumulator (
    input clk,
    input rst,
    input acc_rst,
    input valid_in,

    input signed [47:0] in0,
    input signed [47:0] in1,
    input signed [47:0] in2,
    input signed [47:0] in3,

    output reg signed [47:0] acc,
    output reg valid_out
);

parameter COUNT_LAST = 7'd71;

reg [6:0] cnt;

wire signed [47:0] sum_in;
wire signed [47:0] next_acc;

assign sum_in  = in0 + in1 + in2 + in3;
assign next_acc = acc + sum_in;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        acc <= 48'sd0;
        cnt <= 7'd0;
        valid_out <= 1'b0;
    end else begin
        valid_out <= 1'b0;

        if (acc_rst) begin
            acc <= 48'sd0;
            cnt <= 7'd0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            acc <= next_acc;

            if (cnt == COUNT_LAST) begin
                cnt <= 7'd0;
                valid_out <= 1'b1;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
end

endmodule