`timescale 1ns/1ps

module conv2_window_serializer (
    clk,
    rst,

    win_valid,
    win_in_ch,

    p0, p1, p2,
    p3, p4, p5,
    p6, p7, p8,

    conv2_start,
    conv2_valid_in,
    conv2_in_data,
    conv2_in_ch,
    conv2_k_idx,

    busy
);

input clk;
input rst;

input win_valid;
input [4:0] win_in_ch;

input signed [31:0] p0;
input signed [31:0] p1;
input signed [31:0] p2;
input signed [31:0] p3;
input signed [31:0] p4;
input signed [31:0] p5;
input signed [31:0] p6;
input signed [31:0] p7;
input signed [31:0] p8;

output reg conv2_start;
output reg conv2_valid_in;
output reg signed [31:0] conv2_in_data;
output reg [5:0] conv2_in_ch;
output reg [3:0] conv2_k_idx;

output reg busy;

reg [3:0] send_idx;
reg [5:0] hold_in_ch;

reg signed [31:0] r_p0;
reg signed [31:0] r_p1;
reg signed [31:0] r_p2;
reg signed [31:0] r_p3;
reg signed [31:0] r_p4;
reg signed [31:0] r_p5;
reg signed [31:0] r_p6;
reg signed [31:0] r_p7;
reg signed [31:0] r_p8;

reg [1:0] state;

parameter S_IDLE  = 2'd0;
parameter S_START = 2'd1;
parameter S_SEND  = 2'd2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state          <= S_IDLE;
        busy           <= 1'b0;
        send_idx       <= 4'd0;
        hold_in_ch     <= 6'd0;

        conv2_start    <= 1'b0;
        conv2_valid_in <= 1'b0;
        conv2_in_data  <= 32'sd0;
        conv2_in_ch    <= 6'd0;
        conv2_k_idx    <= 4'd0;

        r_p0 <= 32'sd0;
        r_p1 <= 32'sd0;
        r_p2 <= 32'sd0;
        r_p3 <= 32'sd0;
        r_p4 <= 32'sd0;
        r_p5 <= 32'sd0;
        r_p6 <= 32'sd0;
        r_p7 <= 32'sd0;
        r_p8 <= 32'sd0;
    end
    else begin
        conv2_start    <= 1'b0;
        conv2_valid_in <= 1'b0;

        case (state)

            S_IDLE: begin
                busy <= 1'b0;

                if (win_valid) begin
                    r_p0 <= p0;
                    r_p1 <= p1;
                    r_p2 <= p2;
                    r_p3 <= p3;
                    r_p4 <= p4;
                    r_p5 <= p5;
                    r_p6 <= p6;
                    r_p7 <= p7;
                    r_p8 <= p8;

                    hold_in_ch <= {1'b0, win_in_ch};
                    send_idx   <= 4'd0;
                    busy       <= 1'b1;

                    if (win_in_ch == 5'd0) begin
                        state <= S_START;
                    end
                    else begin
                        state <= S_SEND;
                    end
                end
            end

            S_START: begin
                busy        <= 1'b1;
                conv2_start <= 1'b1;
                state       <= S_SEND;
            end

            S_SEND: begin
                busy           <= 1'b1;
                conv2_valid_in <= 1'b1;
                conv2_in_ch    <= hold_in_ch;
                conv2_k_idx    <= send_idx;

                case (send_idx)
                    4'd0: conv2_in_data <= r_p0;
                    4'd1: conv2_in_data <= r_p1;
                    4'd2: conv2_in_data <= r_p2;
                    4'd3: conv2_in_data <= r_p3;
                    4'd4: conv2_in_data <= r_p4;
                    4'd5: conv2_in_data <= r_p5;
                    4'd6: conv2_in_data <= r_p6;
                    4'd7: conv2_in_data <= r_p7;
                    default: conv2_in_data <= r_p8;
                endcase

                if (send_idx == 4'd8) begin
                    send_idx <= 4'd0;
                    busy     <= 1'b0;
                    state    <= S_IDLE;
                end
                else begin
                    send_idx <= send_idx + 4'd1;
                end
            end

            default: begin
                state <= S_IDLE;
            end

        endcase
    end
end

endmodule