`timescale 1ns/1ps

module dense2_64x1 (
    clk,
    rst,

    valid_in,
    in_data,
    in_idx,

    busy,
    valid_out,
    logit,
    pred,
    done
);

input clk;
input rst;

input valid_in;
input signed [63:0] in_data;
input [5:0] in_idx;

output reg busy;
output reg valid_out;
output reg signed [95:0] logit;
output reg pred;
output reg done;

parameter DENSE2_SHIFT = 8;
parameter PRED_THRESHOLD_Q8_8 = -30;

parameter S_IDLE   = 4'd0;
parameter S_LOAD   = 4'd1;
parameter S_INIT   = 4'd2;
parameter S_ISSUE0 = 4'd3;
parameter S_WAIT0  = 4'd4;
parameter S_MAC    = 4'd5;
parameter S_BIAS   = 4'd6;
parameter S_OUT    = 4'd7;
parameter S_DONE   = 4'd8;

reg [3:0] state;

reg signed [63:0] hidden_mem [0:63];

reg [5:0] load_count;
reg [6:0] rd_idx;
reg [5:0] mac_count;

reg [5:0] hidden_rd_addr;
reg signed [63:0] hidden_dout;

reg [5:0] weight_addr;

wire signed [15:0] weight_dout;
wire signed [95:0] bias_dout;

reg signed [95:0] acc;
reg signed [95:0] logit_reg;
reg pred_reg;

wire signed [79:0] product;
wire signed [95:0] product_ext;

wire signed [95:0] bias_aligned;
wire signed [95:0] sum_bias;
wire signed [95:0] shifted_logit;

wire signed [95:0] pred_threshold_q8_8;

assign product = $signed(hidden_dout) * $signed(weight_dout);
assign product_ext = {{16{product[79]}}, product};

assign bias_aligned = bias_dout <<< DENSE2_SHIFT;
assign sum_bias = acc + bias_aligned;
assign shifted_logit = sum_bias >>> DENSE2_SHIFT;

assign pred_threshold_q8_8 = PRED_THRESHOLD_Q8_8;

dense2_weight_rom u_dense2_weight_rom (
    .clk(clk),
    .addr(weight_addr),
    .dout(weight_dout)
);

dense2_bias_rom u_dense2_bias_rom (
    .clk(clk),
    .dout(bias_dout)
);

always @(posedge clk) begin
    hidden_dout <= hidden_mem[hidden_rd_addr];
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;

        busy <= 1'b0;
        valid_out <= 1'b0;
        logit <= 96'sd0;
        pred <= 1'b0;
        done <= 1'b0;

        load_count <= 6'd0;
        rd_idx <= 7'd0;
        mac_count <= 6'd0;
        hidden_rd_addr <= 6'd0;
        weight_addr <= 6'd0;

        acc <= 96'sd0;
        logit_reg <= 96'sd0;
        pred_reg <= 1'b0;
    end
    else begin
        valid_out <= 1'b0;

        case (state)

            S_IDLE: begin
                busy <= 1'b0;
                done <= 1'b0;

                if (valid_in) begin
                    busy <= 1'b1;
                    hidden_mem[in_idx] <= in_data;
                    load_count <= 6'd1;
                    state <= S_LOAD;
                end
            end

            S_LOAD: begin
                if (valid_in) begin
                    hidden_mem[in_idx] <= in_data;

                    if (load_count == 6'd63) begin
                        state <= S_INIT;
                    end
                    else begin
                        load_count <= load_count + 6'd1;
                    end
                end
            end

            S_INIT: begin
                acc <= 96'sd0;

                rd_idx <= 7'd0;
                mac_count <= 6'd0;

                state <= S_ISSUE0;
            end

            S_ISSUE0: begin
                hidden_rd_addr <= 6'd0;
                weight_addr <= 6'd0;

                rd_idx <= 7'd1;

                state <= S_WAIT0;
            end

            S_WAIT0: begin
                hidden_rd_addr <= 6'd1;
                weight_addr <= 6'd1;

                rd_idx <= 7'd2;

                state <= S_MAC;
            end

            S_MAC: begin
                acc <= acc + product_ext;

                if (mac_count == 6'd63) begin
                    state <= S_BIAS;
                end
                else begin
                    mac_count <= mac_count + 6'd1;

                    if (rd_idx < 7'd64) begin
                        hidden_rd_addr <= rd_idx[5:0];
                        weight_addr <= rd_idx[5:0];
                        rd_idx <= rd_idx + 7'd1;
                    end
                end
            end

            S_BIAS: begin
                logit_reg <= shifted_logit;

                if (shifted_logit >= pred_threshold_q8_8) begin
                    pred_reg <= 1'b1;
                end
                else begin
                    pred_reg <= 1'b0;
                end

                state <= S_OUT;
            end

            S_OUT: begin
                valid_out <= 1'b1;
                logit <= logit_reg;
                pred <= pred_reg;
                done <= 1'b1;
                state <= S_DONE;
            end

            S_DONE: begin
                busy <= 1'b0;

                if (valid_in) begin
                    done <= 1'b0;
                    busy <= 1'b1;
                    hidden_mem[in_idx] <= in_data;
                    load_count <= 6'd1;
                    state <= S_LOAD;
                end
            end

            default: begin
                state <= S_IDLE;
            end

        endcase
    end
end

endmodule
