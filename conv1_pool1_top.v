module conv1_pool1_top (
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
    // pool1 output stream
    // =========================
    output reg signed [31:0] pool_out,
    output reg pool_valid,
    output reg [4:0] pool_row,     // 0 ~ 30
    output reg [4:0] pool_col,     // 0 ~ 30
    output reg [5:0] pool_ch       // 0 ~ 31
);

parameter POOL_OUT_TOTAL = 16'd30752;  // 31 * 31 * 32

// =========================
// conv1 wires
// =========================
wire conv1_busy;
wire conv1_done;

wire signed [31:0] conv1_out;
wire conv1_valid;
wire [5:0] conv1_row;
wire [5:0] conv1_col;
wire [5:0] conv1_ch;

// =========================
// maxpool wires
// =========================
wire signed [31:0] pool_data_w;
wire pool_valid_w;
wire [4:0] pool_row_w;
wire [4:0] pool_col_w;
wire [5:0] pool_ch_w;

reg [15:0] pool_count;

// =========================
// conv1 layer
// =========================
conv1_layer_top u_conv1_layer (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start),

    .busy(conv1_busy),
    .done(conv1_done),

    .conv_out(conv1_out),
    .conv_valid(conv1_valid),
    .conv_row(conv1_row),
    .conv_col(conv1_col),
    .conv_ch(conv1_ch)
);

// =========================
// maxpool1 stream
// input : 62 x 62 x 32
// output: 31 x 31 x 32
// =========================
maxpool1_stream u_pool1 (
    .clk(clk),
    .rst(rst),

    .valid_in(conv1_valid),
    .in_data(conv1_out),
    .in_row(conv1_row),
    .in_col(conv1_col),
    .in_ch(conv1_ch),

    .valid_out(pool_valid_w),
    .out_data(pool_data_w),
    .out_row(pool_row_w),
    .out_col(pool_col_w),
    .out_ch(pool_ch_w)
);

// =========================
// output register + done control
// =========================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        busy <= 1'b0;
        done <= 1'b0;

        pool_out <= 32'sd0;
        pool_valid <= 1'b0;
        pool_row <= 5'd0;
        pool_col <= 5'd0;
        pool_ch <= 6'd0;

        pool_count <= 16'd0;
    end else begin
        done <= 1'b0;
        pool_valid <= 1'b0;

        if (start) begin
            busy <= 1'b1;
            pool_count <= 16'd0;
        end

        if (pool_valid_w) begin
            pool_out <= pool_data_w;
            pool_valid <= 1'b1;
            pool_row <= pool_row_w;
            pool_col <= pool_col_w;
            pool_ch <= pool_ch_w;

            if (pool_count == POOL_OUT_TOTAL - 1) begin
                pool_count <= 16'd0;
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                pool_count <= pool_count + 1'b1;
            end
        end
    end
end

endmodule