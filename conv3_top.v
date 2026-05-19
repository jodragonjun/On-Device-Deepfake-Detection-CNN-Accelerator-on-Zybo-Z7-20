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
input [5:0] in_ch;       // 0~63
input [3:0] k_idx;       // 0~8

output reg signed [31:0] out;
output reg valid_out;
output reg done;

////////////////////////////////////////////////////////////
// State
////////////////////////////////////////////////////////////
parameter S_IDLE     = 3'd0;
parameter S_CAPTURE  = 3'd1;
parameter S_PREP     = 3'd2;
parameter S_WAIT_ROM = 3'd3;
parameter S_MAC      = 3'd4;
parameter S_OUTPUT   = 3'd5;
parameter S_DONE     = 3'd6;

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

reg [2:0] state;

reg signed [31:0] win_buf [0:575];

reg [6:0] out_ch;
reg [7:0] group_idx;

reg signed [47:0] acc;
reg signed [47:0] acc_result;

wire [9:0] store_idx;

wire [9:0] elem_base;
wire [9:0] elem0;
wire [9:0] elem1;
wire [9:0] elem2;
wire [9:0] elem3;

wire [14:0] out_ch_bank_ext;
wire [14:0] oc_base_bank;
wire [14:0] wbank_addr;

wire signed [15:0] w0;
wire signed [15:0] w1;
wire signed [15:0] w2;
wire signed [15:0] w3;

wire signed [15:0] bias;
wire signed [47:0] bias_ext;

wire signed [47:0] pe0;
wire signed [47:0] pe1;
wire signed [47:0] pe2;
wire signed [47:0] pe3;

wire signed [47:0] group_sum;
wire signed [47:0] acc_next;
wire signed [47:0] acc_bias_next;

integer i;

////////////////////////////////////////////////////////////
// Input capture address
// index = in_ch * 9 + k_idx
////////////////////////////////////////////////////////////
assign store_idx = ({4'd0, in_ch} << 3) + {4'd0, in_ch} + {6'd0, k_idx};

////////////////////////////////////////////////////////////
// 4-lane group index
// group_idx 0~143
// elem_base = group_idx * 4
////////////////////////////////////////////////////////////
assign elem_base = {group_idx, 2'b00};

assign elem0 = elem_base;
assign elem1 = elem_base + 10'd1;
assign elem2 = elem_base + 10'd2;
assign elem3 = elem_base + 10'd3;

////////////////////////////////////////////////////////////
// Conv3 weight address
// weight layout: out_ch -> in_ch -> kernel
// addr = out_ch * 576 + elem
// 576 = 512 + 64
////////////////////////////////////////////////////////////
assign out_ch_bank_ext = {8'd0, out_ch};

/* bank address = out_ch * 144 + group_idx
   144 = 128 + 16
*/
assign oc_base_bank = (out_ch_bank_ext << 7) + (out_ch_bank_ext << 4);
assign wbank_addr   = oc_base_bank + {7'd0, group_idx};
assign bias_ext = {{32{bias[15]}}, bias};

////////////////////////////////////////////////////////////
// PE / ACC
////////////////////////////////////////////////////////////
assign group_sum     = pe0 + pe1 + pe2 + pe3;
assign acc_next      = acc + group_sum;
assign acc_bias_next = acc_next + bias_ext;

////////////////////////////////////////////////////////////
// ROM
// 반드시 clk 연결 필요
////////////////////////////////////////////////////////////
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
// Combinational PE
// pe32x16_comb: out = (a*b) >>> 8
////////////////////////////////////////////////////////////
pe32x16_comb u_pe0 (
    .a(win_buf[elem0]),
    .b(w0),
    .out(pe0)
);

pe32x16_comb u_pe1 (
    .a(win_buf[elem1]),
    .b(w1),
    .out(pe1)
);

pe32x16_comb u_pe2 (
    .a(win_buf[elem2]),
    .b(w2),
    .out(pe2)
);

pe32x16_comb u_pe3 (
    .a(win_buf[elem3]),
    .b(w3),
    .out(pe3)
);

////////////////////////////////////////////////////////////
// FSM
////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state     <= S_IDLE;
        out_ch    <= 7'd0;
        group_idx <= 8'd0;

        acc        <= 48'sd0;
        acc_result <= 48'sd0;

        out       <= 32'sd0;
        valid_out <= 1'b0;
        done      <= 1'b0;

        for (i = 0; i < 576; i = i + 1) begin
            win_buf[i] <= 32'sd0;
        end
    end
    else begin
        valid_out <= 1'b0;
        done      <= 1'b0;

        case (state)

            S_IDLE: begin
                out_ch    <= 7'd0;
                group_idx <= 8'd0;
                acc       <= 48'sd0;

                if (start) begin
                    state <= S_CAPTURE;
                end
            end

            S_CAPTURE: begin
                if (valid_in) begin
                    win_buf[store_idx] <= in_data;

                    if ((in_ch == 6'd63) && (k_idx == 4'd8)) begin
                        out_ch    <= 7'd0;
                        group_idx <= 8'd0;
                        acc       <= 48'sd0;
                        state     <= S_PREP;
                    end
                end
            end

            S_PREP: begin
                acc       <= 48'sd0;
                group_idx <= 8'd0;
                state     <= S_WAIT_ROM;
            end

            S_WAIT_ROM: begin
                state <= S_MAC;
            end

            S_MAC: begin
                acc <= acc_next;

                if (group_idx == GROUP_LAST) begin
                    acc_result <= acc_bias_next;
                    state      <= S_OUTPUT;
                end
                else begin
                    group_idx <= group_idx + 8'd1;
                    state     <= S_WAIT_ROM;
                end
            end

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
                    state  <= S_PREP;
                end
            end

            S_DONE: begin
                done  <= 1'b1;
                state <= S_IDLE;
            end

            default: begin
                state <= S_IDLE;
            end

        endcase
    end
end

endmodule