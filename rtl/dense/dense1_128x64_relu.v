`timescale 1ns/1ps

module dense1_128x64_relu (
    clk,
    rst,

    valid_in,
    in_data,
    in_idx,

    busy,
    valid_out,
    out_data,
    out_idx,
    done
);

input clk;
input rst;

input valid_in;
input signed [63:0] in_data;
input [6:0] in_idx;

output reg busy;
output reg valid_out;
output reg signed [63:0] out_data;
output reg [5:0] out_idx;
output reg done;

parameter DENSE1_SHIFT = 8;

parameter S_IDLE       = 4'd0;
parameter S_LOAD       = 4'd1;
parameter S_INIT       = 4'd2;
parameter S_ISSUE0     = 4'd3;
parameter S_WAIT0      = 4'd4;
parameter S_MAC        = 4'd5;
parameter S_BIAS_RELU  = 4'd6;
parameter S_OUT        = 4'd7;
parameter S_NEXT       = 4'd8;
parameter S_DONE       = 4'd9;

reg [3:0] state;

reg signed [63:0] feature_mem [0:127];

reg [6:0] load_count;
reg [7:0] rd_idx;
reg [6:0] mac_count;

reg [6:0] feature_rd_addr;
reg signed [63:0] feature_dout;

reg [5:0] neuron_idx;
reg [12:0] weight_addr;
reg [5:0] bias_addr;

wire signed [15:0] weight_dout;
wire signed [95:0] bias_dout;

reg signed [95:0] acc;
reg signed [63:0] relu_reg;

wire signed [79:0] product;
wire signed [95:0] product_ext;

wire signed [95:0] bias_aligned;
wire signed [95:0] sum_bias;
wire signed [95:0] shifted_value;
wire signed [63:0] relu_value;

assign product = $signed(feature_dout) * $signed(weight_dout);
assign product_ext = {{16{product[79]}}, product};

assign bias_aligned = bias_dout <<< DENSE1_SHIFT;
assign sum_bias = acc + bias_aligned;
assign shifted_value = sum_bias >>> DENSE1_SHIFT;

assign relu_value = shifted_value[95] ? 64'sd0 : shifted_value[63:0];

dense1_weight_rom u_dense1_weight_rom (
    .clk(clk),
    .addr(weight_addr),
    .dout(weight_dout)
);

dense1_bias_rom u_dense1_bias_rom (
    .clk(clk),
    .addr(bias_addr),
    .dout(bias_dout)
);

always @(posedge clk) begin
    feature_dout <= feature_mem[feature_rd_addr];
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;

        busy <= 1'b0;
        valid_out <= 1'b0;
        out_data <= 64'sd0;
        out_idx <= 6'd0;
        done <= 1'b0;

        load_count <= 7'd0;
        rd_idx <= 8'd0;
        mac_count <= 7'd0;
        feature_rd_addr <= 7'd0;

        neuron_idx <= 6'd0;
        weight_addr <= 13'd0;
        bias_addr <= 6'd0;

        acc <= 96'sd0;
        relu_reg <= 64'sd0;
    end
    else begin
        valid_out <= 1'b0;

        case (state)

            S_IDLE: begin
                busy <= 1'b0;
                done <= 1'b0;

                if (valid_in) begin
                    busy <= 1'b1;
                    feature_mem[in_idx] <= in_data;
                    load_count <= 7'd1;
                    state <= S_LOAD;
                end
            end

            S_LOAD: begin
                if (valid_in) begin
                    feature_mem[in_idx] <= in_data;

                    if (load_count == 7'd127) begin
                        neuron_idx <= 6'd0;
                        state <= S_INIT;
                    end
                    else begin
                        load_count <= load_count + 7'd1;
                    end
                end
            end

            S_INIT: begin
                acc <= 96'sd0;

                rd_idx <= 8'd0;
                mac_count <= 7'd0;

                bias_addr <= neuron_idx;

                state <= S_ISSUE0;
            end

            S_ISSUE0: begin
                feature_rd_addr <= 7'd0;
                weight_addr <= {7'd0, 6'b000000} + {7'b0000000, neuron_idx};

                rd_idx <= 8'd1;

                state <= S_WAIT0;
            end

            S_WAIT0: begin
                feature_rd_addr <= 7'd1;
                weight_addr <= {7'd1, 6'b000000} + {7'b0000000, neuron_idx};

                rd_idx <= 8'd2;

                state <= S_MAC;
            end

            S_MAC: begin
                acc <= acc + product_ext;

                if (mac_count == 7'd127) begin
                    state <= S_BIAS_RELU;
                end
                else begin
                    mac_count <= mac_count + 7'd1;

                    if (rd_idx < 8'd128) begin
                        feature_rd_addr <= rd_idx[6:0];
                        weight_addr <= {rd_idx[6:0], 6'b000000} + {7'b0000000, neuron_idx};
                        rd_idx <= rd_idx + 8'd1;
                    end
                end
            end

            S_BIAS_RELU: begin
                relu_reg <= relu_value;
                state <= S_OUT;
            end

            S_OUT: begin
                valid_out <= 1'b1;
                out_idx <= neuron_idx;
                out_data <= relu_reg;

                if (neuron_idx == 6'd63) begin
                    done <= 1'b1;
                    state <= S_DONE;
                end
                else begin
                    state <= S_NEXT;
                end
            end

            S_NEXT: begin
                neuron_idx <= neuron_idx + 6'd1;
                state <= S_INIT;
            end

            S_DONE: begin
                busy <= 1'b0;

                if (valid_in) begin
                    done <= 1'b0;
                    busy <= 1'b1;
                    feature_mem[in_idx] <= in_data;
                    load_count <= 7'd1;
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
