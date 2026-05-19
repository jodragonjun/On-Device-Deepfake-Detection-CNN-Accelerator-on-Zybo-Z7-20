module conv1_top (
    input clk,
    input rst,
    input start,

    input signed [15:0] r00, r01, r02,
    input signed [15:0] r10, r11, r12,
    input signed [15:0] r20, r21, r22,

    input signed [15:0] g00, g01, g02,
    input signed [15:0] g10, g11, g12,
    input signed [15:0] g20, g21, g22,

    input signed [15:0] b00, b01, b02,
    input signed [15:0] b10, b11, b12,
    input signed [15:0] b20, b21, b22,

    output signed [31:0] out,
    output valid_out,
    output done
);

wire [5:0] out_ch;
wire [1:0] in_ch;
wire [3:0] k_idx;

wire acc_rst;
wire mac_en;
wire relu_en;

wire [9:0] addr;
wire [9:0] addr0;
wire [9:0] addr1;
wire [9:0] addr2;
wire [9:0] addr3;

wire signed [15:0] w0;
wire signed [15:0] w1;
wire signed [15:0] w2;
wire signed [15:0] w3;

wire signed [15:0] bias;

reg signed [15:0] bias_reg;
reg acc_rst_d1;

reg signed [15:0] sel0;
reg signed [15:0] sel1;
reg signed [15:0] sel2;
reg signed [15:0] sel3;

reg signed [15:0] sel0_d1;
reg signed [15:0] sel1_d1;
reg signed [15:0] sel2_d1;
reg signed [15:0] sel3_d1;

wire lane0;
wire lane1;
wire lane2;
wire lane3;

reg lane0_d1;
reg lane1_d1;
reg lane2_d1;
reg lane3_d1;

wire signed [15:0] pe_a0;
wire signed [15:0] pe_a1;
wire signed [15:0] pe_a2;
wire signed [15:0] pe_a3;

wire signed [15:0] pe_b0;
wire signed [15:0] pe_b1;
wire signed [15:0] pe_b2;
wire signed [15:0] pe_b3;

wire pe_input_valid;

wire signed [31:0] p0;
wire signed [31:0] p1;
wire signed [31:0] p2;
wire signed [31:0] p3;
wire pe_valid;

wire signed [31:0] acc_out;
wire acc_valid;

wire signed [31:0] acc_bias;
wire signed [31:0] relu_out;
wire relu_valid;

reg acc_valid_d1;
reg signed [31:0] relu_in_reg;

assign out = relu_out;
assign valid_out = relu_valid;

/* ============================================================
   weight address guard
   weight depth = 32 * 3 * 9 = 864
   valid addr   = 0 ~ 863
   ============================================================ */
assign addr0 = addr;
assign addr1 = (addr <= 10'd862) ? (addr + 10'd1) : 10'd0;
assign addr2 = (addr <= 10'd861) ? (addr + 10'd2) : 10'd0;
assign addr3 = (addr <= 10'd860) ? (addr + 10'd3) : 10'd0;

/* ============================================================
   lane valid
   k_idx = 8에서는 lane0만 실제 사용
   ============================================================ */
assign lane0 = 1'b1;
assign lane1 = (k_idx != 4'd8);
assign lane2 = (k_idx != 4'd8);
assign lane3 = (k_idx != 4'd8);

/* ============================================================
   PE input
   weight_rom_conv1은 synchronous ROM.
   따라서 pixel selector 출력은 sel_d1으로 1클럭 delay.
   하지만 valid는 mac_en을 그대로 사용해야 함.
   ============================================================ */
assign pe_a0 = sel0_d1;
assign pe_a1 = sel1_d1;
assign pe_a2 = sel2_d1;
assign pe_a3 = sel3_d1;

assign pe_b0 = lane0_d1 ? w0 : 16'sd0;
assign pe_b1 = lane1_d1 ? w1 : 16'sd0;
assign pe_b2 = lane2_d1 ? w2 : 16'sd0;
assign pe_b3 = lane3_d1 ? w3 : 16'sd0;

assign pe_input_valid = mac_en;

/* ============================================================
   bias timing
   bias ROM도 synchronous ROM.
   acc_rst 이후 1클럭 뒤 bias_reg에 고정.
   ============================================================ */
assign acc_bias = acc_out + {{16{bias_reg[15]}}, bias_reg};

always @(posedge clk or posedge rst) begin
    if (rst) begin
        acc_rst_d1 <= 1'b0;
        bias_reg   <= 16'sd0;
    end else begin
        acc_rst_d1 <= acc_rst;

        if (acc_rst_d1) begin
            bias_reg <= bias;
        end
    end
end

/* ============================================================
   ReLU input timing
   accumulator가 최종 누산 완료를 알리는 acc_valid 기준.
   ============================================================ */
always @(posedge clk or posedge rst) begin
    if (rst) begin
        acc_valid_d1 <= 1'b0;
        relu_in_reg  <= 32'sd0;
    end else begin
        acc_valid_d1 <= acc_valid;

        if (acc_valid) begin
            relu_in_reg <= acc_bias;
        end
    end
end

/* ============================================================
   3x3 RGB selector
   k_idx = 0 : 0,1,2,3
   k_idx = 4 : 4,5,6,7
   k_idx = 8 : 8 only
   ============================================================ */
always @(*) begin
    sel0 = 16'sd0;
    sel1 = 16'sd0;
    sel2 = 16'sd0;
    sel3 = 16'sd0;

    case (in_ch)
        2'd0: begin
            case (k_idx)
                4'd0: begin
                    sel0 = r00;
                    sel1 = r01;
                    sel2 = r02;
                    sel3 = r10;
                end

                4'd4: begin
                    sel0 = r11;
                    sel1 = r12;
                    sel2 = r20;
                    sel3 = r21;
                end

                4'd8: begin
                    sel0 = r22;
                    sel1 = 16'sd0;
                    sel2 = 16'sd0;
                    sel3 = 16'sd0;
                end

                default: begin
                    sel0 = 16'sd0;
                    sel1 = 16'sd0;
                    sel2 = 16'sd0;
                    sel3 = 16'sd0;
                end
            endcase
        end

        2'd1: begin
            case (k_idx)
                4'd0: begin
                    sel0 = g00;
                    sel1 = g01;
                    sel2 = g02;
                    sel3 = g10;
                end

                4'd4: begin
                    sel0 = g11;
                    sel1 = g12;
                    sel2 = g20;
                    sel3 = g21;
                end

                4'd8: begin
                    sel0 = g22;
                    sel1 = 16'sd0;
                    sel2 = 16'sd0;
                    sel3 = 16'sd0;
                end

                default: begin
                    sel0 = 16'sd0;
                    sel1 = 16'sd0;
                    sel2 = 16'sd0;
                    sel3 = 16'sd0;
                end
            endcase
        end

        2'd2: begin
            case (k_idx)
                4'd0: begin
                    sel0 = b00;
                    sel1 = b01;
                    sel2 = b02;
                    sel3 = b10;
                end

                4'd4: begin
                    sel0 = b11;
                    sel1 = b12;
                    sel2 = b20;
                    sel3 = b21;
                end

                4'd8: begin
                    sel0 = b22;
                    sel1 = 16'sd0;
                    sel2 = 16'sd0;
                    sel3 = 16'sd0;
                end

                default: begin
                    sel0 = 16'sd0;
                    sel1 = 16'sd0;
                    sel2 = 16'sd0;
                    sel3 = 16'sd0;
                end
            endcase
        end

        default: begin
            sel0 = 16'sd0;
            sel1 = 16'sd0;
            sel2 = 16'sd0;
            sel3 = 16'sd0;
        end
    endcase
end

/* ============================================================
   selector / lane delay
   ============================================================ */
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sel0_d1 <= 16'sd0;
        sel1_d1 <= 16'sd0;
        sel2_d1 <= 16'sd0;
        sel3_d1 <= 16'sd0;

        lane0_d1 <= 1'b0;
        lane1_d1 <= 1'b0;
        lane2_d1 <= 1'b0;
        lane3_d1 <= 1'b0;
    end else begin
        sel0_d1 <= sel0;
        sel1_d1 <= sel1;
        sel2_d1 <= sel2;
        sel3_d1 <= sel3;

        lane0_d1 <= lane0;
        lane1_d1 <= lane1;
        lane2_d1 <= lane2;
        lane3_d1 <= lane3;
    end
end

/* ============================================================
   FSM
   ============================================================ */
conv1_fsm u_fsm (
    .clk(clk),
    .rst(rst),
    .start(start),
    .acc_done(acc_valid),
    .done(done),

    .out_ch(out_ch),
    .in_ch(in_ch),
    .k_idx(k_idx),

    .acc_rst(acc_rst),
    .mac_en(mac_en),
    .relu_en(relu_en)
);

/* ============================================================
   address generator
   ============================================================ */
addr_gen_conv1 u_addr (
    .out_ch(out_ch),
    .in_ch(in_ch),
    .k_idx(k_idx),
    .addr(addr)
);

/* ============================================================
   weight ROMs
   ============================================================ */
weight_rom_conv1 u_rom0 (
    .clk(clk),
    .addr(addr0),
    .data(w0)
);

weight_rom_conv1 u_rom1 (
    .clk(clk),
    .addr(addr1),
    .data(w1)
);

weight_rom_conv1 u_rom2 (
    .clk(clk),
    .addr(addr2),
    .data(w2)
);

weight_rom_conv1 u_rom3 (
    .clk(clk),
    .addr(addr3),
    .data(w3)
);

/* ============================================================
   bias ROM
   ============================================================ */
bias_rom_conv1 u_bias (
    .clk(clk),
    .addr(out_ch),
    .data(bias)
);

/* ============================================================
   PE array
   ============================================================ */
pe_array4 u_pe (
    .clk(clk),
    .rst(rst),
    .valid_in(pe_input_valid),

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
accumulator u_acc (
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
   ReLU
   ============================================================ */
relu u_relu (
    .clk(clk),
    .rst(rst),
    .valid_in(acc_valid_d1),
    .in(relu_in_reg),
    .out(relu_out),
    .valid_out(relu_valid)
);

endmodule