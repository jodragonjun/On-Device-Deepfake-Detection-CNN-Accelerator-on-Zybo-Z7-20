`timescale 1ns/1ps

module conv3_top (
    clk,
    rst,
    start,

    valid_in,
    in_data,
    in_ch,
    k_idx,

    out,
    valid_out,
    done
);

input clk;
input rst;
input start;

input valid_in;
input signed [31:0] in_data;
input [5:0] in_ch;
input [3:0] k_idx;

output reg signed [31:0] out;
output reg valid_out;
output reg done;

////////////////////////////////////////////////////////////
// State
////////////////////////////////////////////////////////////
parameter S_IDLE      = 4'd0;
parameter S_CAPTURE   = 4'd1;
parameter S_PREP      = 4'd2;
parameter S_ISSUE     = 4'd3;
parameter S_LATCH     = 4'd4;
parameter S_MUL       = 4'd5;
parameter S_SUM1      = 4'd6;
parameter S_SUM2      = 4'd7;
parameter S_ACC       = 4'd8;
parameter S_BIAS      = 4'd9;
parameter S_OUTPUT    = 4'd10;
parameter S_DONE      = 4'd11;

////////////////////////////////////////////////////////////
// Conv3 parameter
////////////////////////////////////////////////////////////
// input  : 64ch * 3 * 3 = 576
// output : 128ch
// 4-lane group : 576 / 4 = 144 groups
////////////////////////////////////////////////////////////
parameter TOTAL_IN_LAST = 10'd575;
parameter GROUP_LAST    = 8'd143;
parameter OUT_CH_LAST   = 7'd127;

reg [3:0] state;

////////////////////////////////////////////////////////////
// 4-bank window buffer
//
// Original linear index:
//   store_idx = in_ch * 9 + k_idx
//
// Since Conv3 MAC always reads four consecutive elements:
//   elem0 = group_idx*4 + 0
//   elem1 = group_idx*4 + 1
//   elem2 = group_idx*4 + 2
//   elem3 = group_idx*4 + 3
//
// Split into 4 banks:
//   bank0[group_idx] = linear[group_idx*4 + 0]
//   bank1[group_idx] = linear[group_idx*4 + 1]
//   bank2[group_idx] = linear[group_idx*4 + 2]
//   bank3[group_idx] = linear[group_idx*4 + 3]
////////////////////////////////////////////////////////////
(* ram_style = "block" *) reg signed [31:0] win_bank0 [0:143];
(* ram_style = "block" *) reg signed [31:0] win_bank1 [0:143];
(* ram_style = "block" *) reg signed [31:0] win_bank2 [0:143];
(* ram_style = "block" *) reg signed [31:0] win_bank3 [0:143];

reg signed [31:0] win_dout0;
reg signed [31:0] win_dout1;
reg signed [31:0] win_dout2;
reg signed [31:0] win_dout3;

wire [9:0] store_idx;
wire [1:0] store_bank;
wire [7:0] store_addr;

wire win_we0;
wire win_we1;
wire win_we2;
wire win_we3;

assign store_idx  = ({4'd0, in_ch} << 3) + {4'd0, in_ch} + {6'd0, k_idx};
assign store_bank = store_idx[1:0];
assign store_addr = store_idx[9:2];

assign win_we0 = (state == S_CAPTURE) && valid_in && (store_bank == 2'd0);
assign win_we1 = (state == S_CAPTURE) && valid_in && (store_bank == 2'd1);
assign win_we2 = (state == S_CAPTURE) && valid_in && (store_bank == 2'd2);
assign win_we3 = (state == S_CAPTURE) && valid_in && (store_bank == 2'd3);

////////////////////////////////////////////////////////////
// Control registers
////////////////////////////////////////////////////////////
reg [6:0] out_ch;
reg [7:0] group_idx;

reg signed [47:0] acc;
reg signed [47:0] acc_result;

////////////////////////////////////////////////////////////
// Weight / bias address
////////////////////////////////////////////////////////////
wire [14:0] out_ch_bank_ext;
wire [14:0] oc_base_bank;
wire [14:0] wbank_addr;

assign out_ch_bank_ext = {8'd0, out_ch};

/*
    bank address = out_ch * 144 + group_idx
    144 = 128 + 16
*/
assign oc_base_bank = (out_ch_bank_ext << 7) + (out_ch_bank_ext << 4);
assign wbank_addr   = oc_base_bank + {7'd0, group_idx};

////////////////////////////////////////////////////////////
// ROM outputs
////////////////////////////////////////////////////////////
wire signed [15:0] w0;
wire signed [15:0] w1;
wire signed [15:0] w2;
wire signed [15:0] w3;

wire signed [15:0] bias;
wire signed [47:0] bias_ext;

assign bias_ext = {{32{bias[15]}}, bias};

weight_rom_conv3_b0 u_wrom0 (
    .clk(clk),
    .addr(wbank_addr),
    .data(w0)
);

weight_rom_conv3_b1 u_wrom1 (
    .clk(clk),
    .addr(wbank_addr),
    .data(w1)
);

weight_rom_conv3_b2 u_wrom2 (
    .clk(clk),
    .addr(wbank_addr),
    .data(w2)
);

weight_rom_conv3_b3 u_wrom3 (
    .clk(clk),
    .addr(wbank_addr),
    .data(w3)
);

bias_rom_conv3 u_brom (
    .clk(clk),
    .addr(out_ch),
    .data(bias)
);

////////////////////////////////////////////////////////////
// Registered PE inputs
////////////////////////////////////////////////////////////
reg signed [31:0] pe_a0_reg;
reg signed [31:0] pe_a1_reg;
reg signed [31:0] pe_a2_reg;
reg signed [31:0] pe_a3_reg;

reg signed [15:0] pe_b0_reg;
reg signed [15:0] pe_b1_reg;
reg signed [15:0] pe_b2_reg;
reg signed [15:0] pe_b3_reg;

wire signed [47:0] pe0_comb;
wire signed [47:0] pe1_comb;
wire signed [47:0] pe2_comb;
wire signed [47:0] pe3_comb;

reg signed [47:0] pe0_reg;
reg signed [47:0] pe1_reg;
reg signed [47:0] pe2_reg;
reg signed [47:0] pe3_reg;

reg signed [47:0] sum01_reg;
reg signed [47:0] sum23_reg;
reg signed [47:0] group_sum_reg;

wire signed [47:0] acc_plus_group;
reg signed [47:0] acc_sum_reg;

assign acc_plus_group = acc + group_sum_reg;

////////////////////////////////////////////////////////////
// PE
// pe32x16_comb: out = (a*b) >>> 8
////////////////////////////////////////////////////////////
pe32x16_comb u_pe0 (
    .a(pe_a0_reg),
    .b(pe_b0_reg),
    .out(pe0_comb)
);

pe32x16_comb u_pe1 (
    .a(pe_a1_reg),
    .b(pe_b1_reg),
    .out(pe1_comb)
);

pe32x16_comb u_pe2 (
    .a(pe_a2_reg),
    .b(pe_b2_reg),
    .out(pe2_comb)
);

pe32x16_comb u_pe3 (
    .a(pe_a3_reg),
    .b(pe_b3_reg),
    .out(pe3_comb)
);

////////////////////////////////////////////////////////////
// Window RAM block
// No asynchronous reset here.
// This is required for BRAM inference.
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (win_we0) begin
        win_bank0[store_addr] <= in_data;
    end

    if (win_we1) begin
        win_bank1[store_addr] <= in_data;
    end

    if (win_we2) begin
        win_bank2[store_addr] <= in_data;
    end

    if (win_we3) begin
        win_bank3[store_addr] <= in_data;
    end

    win_dout0 <= win_bank0[group_idx];
    win_dout1 <= win_bank1[group_idx];
    win_dout2 <= win_bank2[group_idx];
    win_dout3 <= win_bank3[group_idx];
end

////////////////////////////////////////////////////////////
// FSM
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;

        out_ch <= 7'd0;
        group_idx <= 8'd0;

        acc <= 48'sd0;
        acc_result <= 48'sd0;
        acc_sum_reg <= 48'sd0;

        pe_a0_reg <= 32'sd0;
        pe_a1_reg <= 32'sd0;
        pe_a2_reg <= 32'sd0;
        pe_a3_reg <= 32'sd0;

        pe_b0_reg <= 16'sd0;
        pe_b1_reg <= 16'sd0;
        pe_b2_reg <= 16'sd0;
        pe_b3_reg <= 16'sd0;

        pe0_reg <= 48'sd0;
        pe1_reg <= 48'sd0;
        pe2_reg <= 48'sd0;
        pe3_reg <= 48'sd0;

        sum01_reg <= 48'sd0;
        sum23_reg <= 48'sd0;
        group_sum_reg <= 48'sd0;

        out <= 32'sd0;
        valid_out <= 1'b0;
        done <= 1'b0;
    end
    else begin
        valid_out <= 1'b0;
        done <= 1'b0;

        case (state)

            //////////////////////////////////////////////////
            // Wait for start
            //////////////////////////////////////////////////
            S_IDLE: begin
                out_ch <= 7'd0;
                group_idx <= 8'd0;
                acc <= 48'sd0;
                acc_result <= 48'sd0;

                if (start) begin
                    state <= S_CAPTURE;
                end
            end

            //////////////////////////////////////////////////
            // Capture 64ch x 3x3 = 576 input values.
            // Window memory is fully overwritten every window,
            // so memory reset is unnecessary.
            //////////////////////////////////////////////////
            S_CAPTURE: begin
                if (valid_in) begin
                    if ((in_ch == 6'd63) && (k_idx == 4'd8)) begin
                        out_ch <= 7'd0;
                        group_idx <= 8'd0;
                        acc <= 48'sd0;
                        state <= S_PREP;
                    end
                end
            end

            //////////////////////////////////////////////////
            // Prepare one output channel
            //////////////////////////////////////////////////
            S_PREP: begin
                acc <= 48'sd0;
                acc_result <= 48'sd0;
                group_idx <= 8'd0;
                state <= S_ISSUE;
            end

            //////////////////////////////////////////////////
            // Issue synchronous read address to:
            // - win_bank0~3
            // - weight_rom_conv3_b0~3
            //
            // Data becomes available after this clock edge.
            //////////////////////////////////////////////////
            S_ISSUE: begin
                state <= S_LATCH;
            end

            //////////////////////////////////////////////////
            // Latch BRAM/ROM outputs into PE input registers
            //////////////////////////////////////////////////
            S_LATCH: begin
                pe_a0_reg <= win_dout0;
                pe_a1_reg <= win_dout1;
                pe_a2_reg <= win_dout2;
                pe_a3_reg <= win_dout3;

                pe_b0_reg <= w0;
                pe_b1_reg <= w1;
                pe_b2_reg <= w2;
                pe_b3_reg <= w3;

                state <= S_MUL;
            end

            //////////////////////////////////////////////////
            // Register PE outputs
            //////////////////////////////////////////////////
            S_MUL: begin
                pe0_reg <= pe0_comb;
                pe1_reg <= pe1_comb;
                pe2_reg <= pe2_comb;
                pe3_reg <= pe3_comb;

                state <= S_SUM1;
            end

            //////////////////////////////////////////////////
            // First adder pipeline stage
            //////////////////////////////////////////////////
            S_SUM1: begin
                sum01_reg <= pe0_reg + pe1_reg;
                sum23_reg <= pe2_reg + pe3_reg;

                state <= S_SUM2;
            end

            //////////////////////////////////////////////////
            // Second adder pipeline stage
            //////////////////////////////////////////////////
            S_SUM2: begin
                group_sum_reg <= sum01_reg + sum23_reg;

                state <= S_ACC;
            end

            //////////////////////////////////////////////////
            // Accumulate group result
            //////////////////////////////////////////////////
            S_ACC: begin
                acc_sum_reg <= acc_plus_group;

                if (group_idx == GROUP_LAST) begin
                    state <= S_BIAS;
                end
                else begin
                    acc <= acc_plus_group;
                    group_idx <= group_idx + 8'd1;
                    state <= S_ISSUE;
                end
            end

            //////////////////////////////////////////////////
            // Add bias separately to reduce critical path
            //////////////////////////////////////////////////
            S_BIAS: begin
                acc_result <= acc_sum_reg + bias_ext;
                state <= S_OUTPUT;
            end

            //////////////////////////////////////////////////
            // ReLU and output
            //////////////////////////////////////////////////
            S_OUTPUT: begin
                valid_out <= 1'b1;

                if (acc_result[47] == 1'b1) begin
                    out <= 32'sd0;
                end
                else begin
                    out <= acc_result[31:0];
                end

                if (out_ch == OUT_CH_LAST) begin
                    state <= S_DONE;
                end
                else begin
                    out_ch <= out_ch + 7'd1;
                    state <= S_PREP;
                end
            end

            //////////////////////////////////////////////////
            // Done pulse
            //////////////////////////////////////////////////
            S_DONE: begin
                done <= 1'b1;
                state <= S_IDLE;
            end

            default: begin
                state <= S_IDLE;
            end

        endcase
    end
end

endmodule