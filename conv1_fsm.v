`timescale 1ns/1ps

module conv1_fsm (
    input clk,
    input rst,
    input start,
    input acc_done,

    output reg done,

    output reg [5:0] out_ch,
    output reg [1:0] in_ch,
    output reg [3:0] k_idx,

    output reg acc_rst,
    output reg mac_en,
    output reg relu_en
);

////////////////////////////////////////////////////////////
// State
////////////////////////////////////////////////////////////
parameter IDLE     = 3'd0;
parameter LOAD     = 3'd1;
parameter MAC      = 3'd2;
parameter WAIT_ACC = 3'd3;
parameter RELU     = 3'd4;
parameter NEXT_CH  = 3'd5;
parameter DONE     = 3'd6;

parameter OUT_CH_LAST = 6'd31;

reg [2:0] state;
reg [2:0] next_state;

////////////////////////////////////////////////////////////
// State register
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end

////////////////////////////////////////////////////////////
// Next state logic
////////////////////////////////////////////////////////////
always @(*) begin
    next_state = state;

    case (state)
        IDLE: begin
            if (start) begin
                next_state = LOAD;
            end
            else begin
                next_state = IDLE;
            end
        end

        LOAD: begin
            next_state = MAC;
        end

        MAC: begin
            if ((in_ch == 2'd2) && (k_idx == 4'd8)) begin
                next_state = WAIT_ACC;
            end
            else begin
                next_state = MAC;
            end
        end

        WAIT_ACC: begin
            if (acc_done) begin
                next_state = RELU;
            end
            else begin
                next_state = WAIT_ACC;
            end
        end

        RELU: begin
            if (out_ch == OUT_CH_LAST) begin
                next_state = DONE;
            end
            else begin
                next_state = NEXT_CH;
            end
        end

        NEXT_CH: begin
            next_state = LOAD;
        end

        DONE: begin
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

////////////////////////////////////////////////////////////
// Output / counter logic
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        done    <= 1'b0;

        out_ch  <= 6'd0;
        in_ch   <= 2'd0;
        k_idx   <= 4'd0;

        acc_rst <= 1'b0;
        mac_en  <= 1'b0;
        relu_en <= 1'b0;
    end
    else begin
        done    <= 1'b0;
        acc_rst <= 1'b0;
        mac_en  <= 1'b0;
        relu_en <= 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    out_ch <= 6'd0;
                    in_ch  <= 2'd0;
                    k_idx  <= 4'd0;
                end
            end

            LOAD: begin
                acc_rst <= 1'b1;
                in_ch   <= 2'd0;
                k_idx   <= 4'd0;
            end

            MAC: begin
                mac_en <= 1'b1;

                if (k_idx < 4'd8) begin
                    k_idx <= k_idx + 4'd4;
                end
                else begin
                    k_idx <= 4'd0;

                    if (in_ch < 2'd2) begin
                        in_ch <= in_ch + 2'd1;
                    end
                    else begin
                        in_ch <= in_ch;
                    end
                end
            end

            WAIT_ACC: begin
            end

            RELU: begin
                relu_en <= 1'b1;
            end

            NEXT_CH: begin
                out_ch <= out_ch + 6'd1;
                in_ch  <= 2'd0;
                k_idx  <= 4'd0;
            end

            DONE: begin
                done <= 1'b1;
            end

            default: begin
                done    <= 1'b0;
                acc_rst <= 1'b0;
                mac_en  <= 1'b0;
                relu_en <= 1'b0;
            end
        endcase
    end
end

endmodule