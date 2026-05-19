module conv2_top (
    input clk,
    input rst,
    input start,

    input valid_in,
    input signed [31:0] in_data,
    input [5:0] in_ch,
    input [3:0] k_idx,

    output reg signed [31:0] out,
    output reg valid_out,
    output reg done
);

parameter IDLE      = 4'd0;
parameter CAPTURE   = 4'd1;
parameter LOAD_OC   = 4'd2;
parameter WAIT_ROM  = 4'd3;
parameter FEED_PE   = 4'd4;
parameter WAIT_ACC  = 4'd5;
parameter OUTPUT    = 4'd6;
parameter NEXT_OC   = 4'd7;
parameter DONE_ST   = 4'd8;

parameter TOTAL_IN_LAST = 9'd287;
parameter GROUP_LAST    = 7'd71;
parameter OUT_CH_LAST   = 6'd63;

reg [3:0] state;

reg signed [31:0] win_buf [0:287];

reg [8:0] cap_count;
reg [5:0] out_ch;
reg [6:0] group_idx;

wire [8:0] cap_addr;
wire [8:0] base_idx;

wire [14:0] weight_addr0;
wire [14:0] weight_addr1;
wire [14:0] weight_addr2;
wire [14:0] weight_addr3;

wire signed [15:0] w0;
wire signed [15:0] w1;
wire signed [15:0] w2;
wire signed [15:0] w3;

wire signed [15:0] bias;
reg signed [15:0] bias_reg;

wire [14:0] out_ch_ext;
wire [14:0] base_out_ext;
wire [14:0] base_idx_ext;
wire [14:0] weight_base_addr;

wire signed [31:0] pe_a0;
wire signed [31:0] pe_a1;
wire signed [31:0] pe_a2;
wire signed [31:0] pe_a3;

wire signed [15:0] pe_b0;
wire signed [15:0] pe_b1;
wire signed [15:0] pe_b2;
wire signed [15:0] pe_b3;

wire pe_valid_in;
wire pe_valid;

wire signed [47:0] p0;
wire signed [47:0] p1;
wire signed [47:0] p2;
wire signed [47:0] p3;

reg acc_rst;
wire signed [47:0] acc_out;
wire acc_valid;

wire signed [47:0] bias_ext;
wire signed [47:0] acc_bias;

integer i;

/* ============================================================
   입력 window buffer 주소
   index = in_ch * 9 + k_idx
   ============================================================ */
assign cap_addr = ({3'd0, in_ch} << 3) + {3'd0, in_ch} + {5'd0, k_idx};

/* ============================================================
   PE 4개 단위 index
   group_idx = 0~71
   base_idx  = group_idx * 4
   ============================================================ */
assign base_idx = {group_idx, 2'b00};

/* ============================================================
   weight 주소
   Conv2 weight layout:
   addr = out_ch * 288 + base_idx
   288 = 256 + 32
   ============================================================ */
assign out_ch_ext = {9'd0, out_ch};
assign base_out_ext = (out_ch_ext << 8) + (out_ch_ext << 5);
assign base_idx_ext = {6'd0, base_idx};

assign weight_base_addr = base_out_ext + base_idx_ext;

assign weight_addr0 = weight_base_addr;
assign weight_addr1 = weight_base_addr + 15'd1;
assign weight_addr2 = weight_base_addr + 15'd2;
assign weight_addr3 = weight_base_addr + 15'd3;

/* ============================================================
   PE input
   ============================================================ */
assign pe_a0 = win_buf[base_idx];
assign pe_a1 = win_buf[base_idx + 9'd1];
assign pe_a2 = win_buf[base_idx + 9'd2];
assign pe_a3 = win_buf[base_idx + 9'd3];

assign pe_b0 = w0;
assign pe_b1 = w1;
assign pe_b2 = w2;
assign pe_b3 = w3;

assign pe_valid_in = (state == FEED_PE);

/* ============================================================
   bias + ReLU input
   ============================================================ */
assign bias_ext = {{32{bias_reg[15]}}, bias_reg};
assign acc_bias = acc_out + bias_ext;

/* ============================================================
   ROM
   ============================================================ */
weight_rom_conv2 u_rom0 (
    .clk(clk),
    .addr(weight_addr0),
    .data(w0)
);

weight_rom_conv2 u_rom1 (
    .clk(clk),
    .addr(weight_addr1),
    .data(w1)
);

weight_rom_conv2 u_rom2 (
    .clk(clk),
    .addr(weight_addr2),
    .data(w2)
);

weight_rom_conv2 u_rom3 (
    .clk(clk),
    .addr(weight_addr3),
    .data(w3)
);

bias_rom_conv2 u_bias (
    .clk(clk),
    .addr(out_ch),
    .data(bias)
);

/* ============================================================
   PE array
   ============================================================ */
pe_array4_32x16 u_pe (
    .clk(clk),
    .rst(rst),
    .valid_in(pe_valid_in),

    .a0(pe_a0),
    .a1(pe_a1),
    .a2(pe_a2),
    .a3(pe_a3),

    .b0(pe_b0),
    .b1(pe_b1),
    .b2(pe_b2),
    .b3(pe_b3),

    .o0(p0),
    .o1(p1),
    .o2(p2),
    .o3(p3),

    .valid_out(pe_valid)
);

/* ============================================================
   accumulator
   ============================================================ */
conv2_accumulator u_acc (
    .clk(clk),
    .rst(rst),
    .acc_rst(acc_rst),
    .valid_in(pe_valid),

    .in0(p0),
    .in1(p1),
    .in2(p2),
    .in3(p3),

    .acc(acc_out),
    .valid_out(acc_valid)
);

/* ============================================================
   FSM
   ============================================================ */
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;

        cap_count <= 9'd0;
        out_ch <= 6'd0;
        group_idx <= 7'd0;

        acc_rst <= 1'b0;
        bias_reg <= 16'sd0;

        out <= 32'sd0;
        valid_out <= 1'b0;
        done <= 1'b0;

        for (i = 0; i < 288; i = i + 1) begin
            win_buf[i] <= 32'sd0;
        end
    end else begin
        acc_rst <= 1'b0;
        valid_out <= 1'b0;
        done <= 1'b0;

        case (state)

            IDLE: begin
                cap_count <= 9'd0;
                out_ch <= 6'd0;
                group_idx <= 7'd0;

                if (start) begin
                    state <= CAPTURE;
                end
            end

            CAPTURE: begin
                if (valid_in) begin
                    win_buf[cap_addr] <= in_data;

                    if (cap_count == TOTAL_IN_LAST) begin
                        cap_count <= 9'd0;
                        out_ch <= 6'd0;
                        group_idx <= 7'd0;
                        state <= LOAD_OC;
                    end else begin
                        cap_count <= cap_count + 1'b1;
                    end
                end
            end

            LOAD_OC: begin
                acc_rst <= 1'b1;
                group_idx <= 7'd0;
                state <= WAIT_ROM;
            end

            WAIT_ROM: begin
                state <= FEED_PE;
            end

            FEED_PE: begin
                if (group_idx == 7'd0) begin
                    bias_reg <= bias;
                end

                if (group_idx == GROUP_LAST) begin
                    state <= WAIT_ACC;
                end else begin
                    group_idx <= group_idx + 1'b1;
                    state <= WAIT_ROM;
                end
            end

            WAIT_ACC: begin
                if (acc_valid) begin
                    state <= OUTPUT;
                end
            end

            OUTPUT: begin
                if (acc_bias < 48'sd0) begin
                    out <= 32'sd0;
                end else begin
                    out <= acc_bias[31:0];
                end

                valid_out <= 1'b1;

                if (out_ch == OUT_CH_LAST) begin
                    state <= DONE_ST;
                end else begin
                    state <= NEXT_OC;
                end
            end

            NEXT_OC: begin
                out_ch <= out_ch + 1'b1;
                group_idx <= 7'd0;
                state <= LOAD_OC;
            end

            DONE_ST: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end

        endcase
    end
end

endmodule