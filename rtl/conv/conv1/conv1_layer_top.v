module conv1_layer_top (
    input clk,
    input rst,

    // =========================
    // PS image write interface
    // =========================
    input img_wr_en,
    input [11:0] img_wr_addr,
    input signed [15:0] img_wr_r,
    input signed [15:0] img_wr_g,
    input signed [15:0] img_wr_b,

    // =========================
    // control
    // =========================
    input start,

    output reg busy,
    output reg done,

    // =========================
    // conv1 output stream
    // =========================
    output reg signed [31:0] conv_out,
    output reg conv_valid,
    output reg [5:0] conv_row,     // 0 ~ 61
    output reg [5:0] conv_col,     // 0 ~ 61
    output reg [5:0] conv_ch       // 0 ~ 31
);

parameter IDLE       = 3'd0;
parameter START_WIN  = 3'd1;
parameter WAIT_WIN   = 3'd2;
parameter START_CONV = 3'd3;
parameter WAIT_CONV  = 3'd4;
parameter NEXT_WIN   = 3'd5;
parameter DONE_ST    = 3'd6;

reg [2:0] state;

reg [5:0] row;
reg [5:0] col;
reg [5:0] out_ch_cnt;

reg win_start;
reg conv_start;

// =========================
// image memory wires
// =========================
wire img_rd_en;
wire [11:0] img_rd_addr;

wire signed [15:0] img_rd_r;
wire signed [15:0] img_rd_g;
wire signed [15:0] img_rd_b;
wire img_rd_valid;

// =========================
// window wires
// =========================
wire signed [15:0] r00, r01, r02;
wire signed [15:0] r10, r11, r12;
wire signed [15:0] r20, r21, r22;

wire signed [15:0] g00, g01, g02;
wire signed [15:0] g10, g11, g12;
wire signed [15:0] g20, g21, g22;

wire signed [15:0] b00, b01, b02;
wire signed [15:0] b10, b11, b12;
wire signed [15:0] b20, b21, b22;

wire win_valid;
wire win_done;
wire win_busy;

// =========================
// conv1 wires
// =========================
wire signed [31:0] conv1_out;
wire conv1_valid;
wire conv1_done;

// =========================
// image memory
// =========================
image_mem_3ch_64x64 u_img_mem (
    .clk(clk),
    .rst(rst),

    .wr_en(img_wr_en),
    .wr_addr(img_wr_addr),
    .wr_r(img_wr_r),
    .wr_g(img_wr_g),
    .wr_b(img_wr_b),

    .rd_en(img_rd_en),
    .rd_addr(img_rd_addr),

    .rd_r(img_rd_r),
    .rd_g(img_rd_g),
    .rd_b(img_rd_b),
    .rd_valid(img_rd_valid)
);

// =========================
// window generator
// =========================
window_gen_3x3_64 u_win_gen (
    .clk(clk),
    .rst(rst),
    .start(win_start),

    .row(row),
    .col(col),

    .rd_en(img_rd_en),
    .rd_addr(img_rd_addr),

    .rd_r(img_rd_r),
    .rd_g(img_rd_g),
    .rd_b(img_rd_b),
    .rd_valid(img_rd_valid),

    .r00(r00), .r01(r01), .r02(r02),
    .r10(r10), .r11(r11), .r12(r12),
    .r20(r20), .r21(r21), .r22(r22),

    .g00(g00), .g01(g01), .g02(g02),
    .g10(g10), .g11(g11), .g12(g12),
    .g20(g20), .g21(g21), .g22(g22),

    .b00(b00), .b01(b01), .b02(b02),
    .b10(b10), .b11(b11), .b12(b12),
    .b20(b20), .b21(b21), .b22(b22),

    .valid_out(win_valid),
    .done(win_done),
    .busy(win_busy)
);

// =========================
// conv1 core
// =========================
conv1_top u_conv1 (
    .clk(clk),
    .rst(rst),
    .start(conv_start),

    .r00(r00), .r01(r01), .r02(r02),
    .r10(r10), .r11(r11), .r12(r12),
    .r20(r20), .r21(r21), .r22(r22),

    .g00(g00), .g01(g01), .g02(g02),
    .g10(g10), .g11(g11), .g12(g12),
    .g20(g20), .g21(g21), .g22(g22),

    .b00(b00), .b01(b01), .b02(b02),
    .b10(b10), .b11(b11), .b12(b12),
    .b20(b20), .b21(b21), .b22(b22),

    .out(conv1_out),
    .valid_out(conv1_valid),
    .done(conv1_done)
);

// =========================
// layer controller FSM
// =========================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;

        row <= 6'd0;
        col <= 6'd0;
        out_ch_cnt <= 6'd0;

        win_start <= 1'b0;
        conv_start <= 1'b0;

        busy <= 1'b0;
        done <= 1'b0;

        conv_out <= 32'sd0;
        conv_valid <= 1'b0;
        conv_row <= 6'd0;
        conv_col <= 6'd0;
        conv_ch <= 6'd0;
    end else begin
        win_start <= 1'b0;
        conv_start <= 1'b0;
        conv_valid <= 1'b0;
        done <= 1'b0;

        case (state)
            IDLE: begin
                busy <= 1'b0;

                if (start) begin
                    busy <= 1'b1;
                    row <= 6'd0;
                    col <= 6'd0;
                    out_ch_cnt <= 6'd0;
                    state <= START_WIN;
                end
            end

            START_WIN: begin
                busy <= 1'b1;
                win_start <= 1'b1;
                state <= WAIT_WIN;
            end

            WAIT_WIN: begin
                busy <= 1'b1;

                if (win_done) begin
                    state <= START_CONV;
                end
            end

            START_CONV: begin
                busy <= 1'b1;
                conv_start <= 1'b1;
                out_ch_cnt <= 6'd0;
                state <= WAIT_CONV;
            end

            WAIT_CONV: begin
                busy <= 1'b1;

                if (conv1_valid) begin
                    conv_out <= conv1_out;
                    conv_valid <= 1'b1;

                    conv_row <= row;
                    conv_col <= col;
                    conv_ch <= out_ch_cnt;

                    if (out_ch_cnt < 6'd31) begin
                        out_ch_cnt <= out_ch_cnt + 1'b1;
                    end
                end

                if (conv1_done) begin
                    state <= NEXT_WIN;
                end
            end

            NEXT_WIN: begin
                busy <= 1'b1;

                if (col == 6'd61) begin
                    col <= 6'd0;

                    if (row == 6'd61) begin
                        row <= 6'd0;
                        state <= DONE_ST;
                    end else begin
                        row <= row + 1'b1;
                        state <= START_WIN;
                    end
                end else begin
                    col <= col + 1'b1;
                    state <= START_WIN;
                end
            end

            DONE_ST: begin
                busy <= 1'b0;
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