`timescale 1ns/1ps

module tb_cnn_full_inference_top;

reg clk;
reg rst;

reg img_wr_en;
reg [11:0] img_wr_addr;
reg signed [15:0] img_wr_r;
reg signed [15:0] img_wr_g;
reg signed [15:0] img_wr_b;

reg start;

wire final_valid;
wire signed [95:0] final_logit;
wire final_pred;
wire final_done;

wire feature_busy;
wire feature_done;
wire tail_busy;

integer i;
integer pool3_count;
integer gap_count;
integer dense1_count;
integer final_count;
integer xz_err_count;

reg signed [15:0] img_r_mem [0:4095];
reg signed [15:0] img_g_mem [0:4095];
reg signed [15:0] img_b_mem [0:4095];

cnn_full_inference_top dut (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start),

    .final_valid(final_valid),
    .final_logit(final_logit),
    .final_pred(final_pred),
    .final_done(final_done),

    .feature_busy(feature_busy),
    .feature_done(feature_done),
    .tail_busy(tail_busy)
);

always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst = 1'b1;

    img_wr_en = 1'b0;
    img_wr_addr = 12'd0;
    img_wr_r = 16'sd0;
    img_wr_g = 16'sd0;
    img_wr_b = 16'sd0;

    start = 1'b0;

    pool3_count = 0;
    gap_count = 0;
    dense1_count = 0;
    final_count = 0;
    xz_err_count = 0;

    //////////////////////////////////////////////////
    // 이미지 입력 hex 경로
    // 네 파일명에 맞게 수정
    //////////////////////////////////////////////////

    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_r.hex", img_r_mem);
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_g.hex", img_g_mem);
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_b.hex", img_b_mem);

    //////////////////////////////////////////////////
    // reset
    //////////////////////////////////////////////////

    #100;
    rst = 1'b0;
    #50;

    //////////////////////////////////////////////////
    // image RAM write: 64 x 64 = 4096
    //////////////////////////////////////////////////

    for (i = 0; i < 4096; i = i + 1) begin
        @(posedge clk);
        img_wr_en   <= 1'b1;
        img_wr_addr <= i[11:0];
        img_wr_r    <= img_r_mem[i];
        img_wr_g    <= img_g_mem[i];
        img_wr_b    <= img_b_mem[i];
    end

    @(posedge clk);
    img_wr_en   <= 1'b0;
    img_wr_addr <= 12'd0;
    img_wr_r    <= 16'sd0;
    img_wr_g    <= 16'sd0;
    img_wr_b    <= 16'sd0;

    //////////////////////////////////////////////////
    // start pulse
    //////////////////////////////////////////////////

    repeat (10) @(posedge clk);

    @(posedge clk);
    start <= 1'b1;

    @(posedge clk);
    start <= 1'b0;

    //////////////////////////////////////////////////
    // wait final_done
    //////////////////////////////////////////////////

    wait(final_done == 1'b1);

    repeat (20) @(posedge clk);

    //////////////////////////////////////////////////
    // result
    //////////////////////////////////////////////////

    $display("==================================================");
    $display("[FULL CNN RESULT]");
    $display("pool3_count  = %0d / expected 4608", pool3_count);
    $display("gap_count    = %0d / expected 128", gap_count);
    $display("dense1_count = %0d / expected 64", dense1_count);
    $display("final_count  = %0d / expected 1", final_count);
    $display("xz_err_count = %0d", xz_err_count);
    $display("final_logit  = %0d", final_logit);
    $display("final_pred   = %0d", final_pred);
    $display("==================================================");

    if ((pool3_count == 4608) &&
        (gap_count == 128) &&
        (dense1_count == 64) &&
        (final_count == 1) &&
        (xz_err_count == 0)) begin
        $display("[TB DONE] Structure verification PASS");
    end
    else begin
        $display("[TB FAIL] Count or X/Z error detected");
    end

    $finish;
end

//////////////////////////////////////////////////
// 내부 valid count
// 시뮬레이션 검증용 hierarchical reference
//////////////////////////////////////////////////

always @(posedge clk) begin
    if (rst) begin
        pool3_count <= 0;
        gap_count <= 0;
        dense1_count <= 0;
        final_count <= 0;
        xz_err_count <= 0;
    end
    else begin
        if (dut.u_feature_extractor.pool3_valid) begin
            pool3_count <= pool3_count + 1;

            if ((^dut.u_feature_extractor.pool3_out === 1'bx) ||
                (^dut.u_feature_extractor.pool3_row === 1'bx) ||
                (^dut.u_feature_extractor.pool3_col === 1'bx) ||
                (^dut.u_feature_extractor.pool3_ch  === 1'bx)) begin
                xz_err_count <= xz_err_count + 1;
            end
        end

        if (dut.u_classifier_tail.u_gap.valid_out) begin
            gap_count <= gap_count + 1;

            if ((^dut.u_classifier_tail.u_gap.out_data === 1'bx) ||
                (^dut.u_classifier_tail.u_gap.out_ch   === 1'bx)) begin
                xz_err_count <= xz_err_count + 1;
            end
        end

        if (dut.u_classifier_tail.u_dense1.valid_out) begin
            dense1_count <= dense1_count + 1;

            if ((^dut.u_classifier_tail.u_dense1.out_data === 1'bx) ||
                (^dut.u_classifier_tail.u_dense1.out_idx  === 1'bx)) begin
                xz_err_count <= xz_err_count + 1;
            end
        end

        if (final_valid) begin
            final_count <= final_count + 1;

            if ((^final_logit === 1'bx) ||
                (final_pred === 1'bx)) begin
                xz_err_count <= xz_err_count + 1;
            end

            $display("[FINAL] logit=%0d pred=%0d time=%0t",
                     final_logit, final_pred, $time);
        end
    end
end

endmodule