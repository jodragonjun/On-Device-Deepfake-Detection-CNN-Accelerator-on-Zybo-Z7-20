`timescale 1ns/1ps

module tb_cnn_full_batch;

parameter NUM_TEST = 10;
parameter PIXELS = 4096;
parameter TOTAL_PIXELS = NUM_TEST * PIXELS;

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

reg signed [15:0] img_r_all [0:TOTAL_PIXELS-1];
reg signed [15:0] img_g_all [0:TOTAL_PIXELS-1];
reg signed [15:0] img_b_all [0:TOTAL_PIXELS-1];

integer label_file;
integer filelist_file;
integer scan_ret;

integer test_idx;
integer pix_idx;
integer base_addr;

integer expected_label;
integer pass_count;
integer fail_count;

integer pool3_count;
integer gap_count;
integer dense1_count;
integer final_count;
integer xz_err_count;

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

task reset_dut;
    begin
        rst <= 1'b1;
        img_wr_en <= 1'b0;
        img_wr_addr <= 12'd0;
        img_wr_r <= 16'sd0;
        img_wr_g <= 16'sd0;
        img_wr_b <= 16'sd0;
        start <= 1'b0;

        repeat (10) @(posedge clk);
        rst <= 1'b0;
        repeat (10) @(posedge clk);
    end
endtask

task write_one_image;
    input integer image_index;
    integer j;
    integer base;
    begin
        base = image_index * PIXELS;

        for (j = 0; j < PIXELS; j = j + 1) begin
            @(posedge clk);
            img_wr_en   <= 1'b1;
            img_wr_addr <= j[11:0];
            img_wr_r    <= img_r_all[base + j];
            img_wr_g    <= img_g_all[base + j];
            img_wr_b    <= img_b_all[base + j];
        end

        @(posedge clk);
        img_wr_en   <= 1'b0;
        img_wr_addr <= 12'd0;
        img_wr_r    <= 16'sd0;
        img_wr_g    <= 16'sd0;
        img_wr_b    <= 16'sd0;
    end
endtask

task start_inference;
    begin
        repeat (10) @(posedge clk);

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;
    end
endtask

initial begin
    clk = 1'b0;
    rst = 1'b1;

    img_wr_en = 1'b0;
    img_wr_addr = 12'd0;
    img_wr_r = 16'sd0;
    img_wr_g = 16'sd0;
    img_wr_b = 16'sd0;

    start = 1'b0;

    pass_count = 0;
    fail_count = 0;

    pool3_count = 0;
    gap_count = 0;
    dense1_count = 0;
    final_count = 0;
    xz_err_count = 0;

    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_r_all.hex", img_r_all);
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_g_all.hex", img_g_all);
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_b_all.hex", img_b_all);

    label_file = $fopen("C:/Xilinx/Vivado/project/capstone/data/labels.txt", "r");

    if (label_file == 0) begin
        $display("[ERROR] labels.txt open failed");
        $finish;
    end

    for (test_idx = 0; test_idx < NUM_TEST; test_idx = test_idx + 1) begin
        scan_ret = $fscanf(label_file, "%d\n", expected_label);

        pool3_count = 0;
        gap_count = 0;
        dense1_count = 0;
        final_count = 0;
        xz_err_count = 0;

        reset_dut();
        write_one_image(test_idx);
        start_inference();

        wait(final_done == 1'b1);
        repeat (20) @(posedge clk);

        $display("--------------------------------------------------");
        $display("[TEST %0d]", test_idx);
        $display("pool3_count  = %0d / 4608", pool3_count);
        $display("gap_count    = %0d / 128", gap_count);
        $display("dense1_count = %0d / 64", dense1_count);
        $display("final_count  = %0d / 1", final_count);
        $display("xz_err_count = %0d", xz_err_count);
        $display("final_logit  = %0d", final_logit);
        $display("final_pred   = %0d", final_pred);
        $display("expected     = %0d", expected_label);

        if ((pool3_count == 4608) &&
            (gap_count == 128) &&
            (dense1_count == 64) &&
            (final_count == 1) &&
            (xz_err_count == 0) &&
            (final_pred == expected_label)) begin
            pass_count = pass_count + 1;
            $display("[PASS]");
        end
        else begin
            fail_count = fail_count + 1;
            $display("[FAIL]");
        end
    end

    $display("==================================================");
    $display("[BATCH TEST DONE]");
    $display("TOTAL = %0d", NUM_TEST);
    $display("PASS  = %0d", pass_count);
    $display("FAIL  = %0d", fail_count);
    $display("ACC   = %0d / %0d", pass_count, NUM_TEST);
    $display("==================================================");

    $finish;
end

always @(posedge clk) begin
    if (!rst) begin
        if (dut.u_feature_extractor.pool3_valid) begin
            pool3_count = pool3_count + 1;

            if ((^dut.u_feature_extractor.pool3_out === 1'bx) ||
                (^dut.u_feature_extractor.pool3_row === 1'bx) ||
                (^dut.u_feature_extractor.pool3_col === 1'bx) ||
                (^dut.u_feature_extractor.pool3_ch  === 1'bx)) begin
                xz_err_count = xz_err_count + 1;
            end
        end

        if (dut.u_classifier_tail.u_gap.valid_out) begin
            gap_count = gap_count + 1;

            if ((^dut.u_classifier_tail.u_gap.out_data === 1'bx) ||
                (^dut.u_classifier_tail.u_gap.out_ch === 1'bx)) begin
                xz_err_count = xz_err_count + 1;
            end
        end

        if (dut.u_classifier_tail.u_dense1.valid_out) begin
            dense1_count = dense1_count + 1;

            if ((^dut.u_classifier_tail.u_dense1.out_data === 1'bx) ||
                (^dut.u_classifier_tail.u_dense1.out_idx === 1'bx)) begin
                xz_err_count = xz_err_count + 1;
            end
        end

        if (final_valid) begin
            final_count = final_count + 1;

            if ((^final_logit === 1'bx) ||
                (final_pred === 1'bx)) begin
                xz_err_count = xz_err_count + 1;
            end

            $display("[FINAL] logit=%0d pred=%0d time=%0t",
                     final_logit, final_pred, $time);
        end
    end
end

endmodule