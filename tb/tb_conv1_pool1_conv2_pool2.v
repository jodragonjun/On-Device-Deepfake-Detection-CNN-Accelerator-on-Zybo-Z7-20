`timescale 1ns/1ps

module tb_conv1_pool1_conv2_pool2_top;

////////////////////////////////////////////////////////////
// Parameter
////////////////////////////////////////////////////////////
parameter IMG_SIZE   = 4096;       // 64*64
parameter CONV2_SIZE = 53824;      // 29*29*64
parameter POOL2_SIZE = 12544;      // 14*14*64

parameter DATA_DIR = "C:/Xilinx/Vivado/project/capstone/data";

////////////////////////////////////////////////////////////
// Clock / Reset
////////////////////////////////////////////////////////////
reg clk;
reg rst;
reg start;

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;         // 100MHz
end

////////////////////////////////////////////////////////////
// DUT input
////////////////////////////////////////////////////////////
reg img_wr_en;
reg [11:0] img_wr_addr;
reg signed [15:0] img_wr_r;
reg signed [15:0] img_wr_g;
reg signed [15:0] img_wr_b;

////////////////////////////////////////////////////////////
// DUT output
////////////////////////////////////////////////////////////
wire signed [31:0] pool2_out;
wire pool2_valid;
wire [3:0] pool2_row;
wire [3:0] pool2_col;
wire [5:0] pool2_ch;

wire busy;
wire done;

wire signed [31:0] dbg_conv2_out;
wire dbg_conv2_valid;
wire [4:0] dbg_conv2_row;
wire [4:0] dbg_conv2_col;
wire [5:0] dbg_conv2_ch;

////////////////////////////////////////////////////////////
// TB memory
////////////////////////////////////////////////////////////
reg signed [15:0] img_r_mem [0:IMG_SIZE-1];
reg signed [15:0] img_g_mem [0:IMG_SIZE-1];
reg signed [15:0] img_b_mem [0:IMG_SIZE-1];

reg signed [31:0] conv2_ref [0:CONV2_SIZE-1];
reg signed [31:0] pool2_ref [0:POOL2_SIZE-1];

////////////////////////////////////////////////////////////
// Counter / Error
////////////////////////////////////////////////////////////
integer i;

integer conv2_count;
integer pool2_count;

integer conv2_err_count;
integer pool2_err_count;
integer conv2_meta_err_count;
integer pool2_meta_err_count;
integer x_err_count;
integer err_count;

integer exp_row;
integer exp_col;
integer exp_ch;

integer fd_conv2_hex;
integer fd_conv2_dec;
integer fd_pool2_hex;
integer fd_pool2_dec;

reg finish_flag;

////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////
conv1_pool1_conv2_pool2_top u_dut (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start),

    .pool2_out(pool2_out),
    .pool2_valid(pool2_valid),
    .pool2_row(pool2_row),
    .pool2_col(pool2_col),
    .pool2_ch(pool2_ch),

    .busy(busy),
    .done(done),

    .dbg_conv2_out(dbg_conv2_out),
    .dbg_conv2_valid(dbg_conv2_valid),
    .dbg_conv2_row(dbg_conv2_row),
    .dbg_conv2_col(dbg_conv2_col),
    .dbg_conv2_ch(dbg_conv2_ch)
);

////////////////////////////////////////////////////////////
// Task: close files
////////////////////////////////////////////////////////////
task close_files;
begin
    if (fd_conv2_hex != 0) $fclose(fd_conv2_hex);
    if (fd_conv2_dec != 0) $fclose(fd_conv2_dec);
    if (fd_pool2_hex != 0) $fclose(fd_pool2_hex);
    if (fd_pool2_dec != 0) $fclose(fd_pool2_dec);
end
endtask

////////////////////////////////////////////////////////////
// Task: print summary
////////////////////////////////////////////////////////////
task print_summary;
begin
    $display("==================================================");
    $display("[TB DONE]");
    $display("conv2 count          = %0d / expected %0d", conv2_count, CONV2_SIZE);
    $display("pool2 count          = %0d / expected %0d", pool2_count, POOL2_SIZE);
    $display("conv2 data err count = %0d", conv2_err_count);
    $display("pool2 data err count = %0d", pool2_err_count);
    $display("conv2 meta err count = %0d", conv2_meta_err_count);
    $display("pool2 meta err count = %0d", pool2_meta_err_count);
    $display("x/z err count        = %0d", x_err_count);
    $display("total err count      = %0d", err_count);
    $display("busy                 = %b", busy);
    $display("done                 = %b", done);
    $display("==================================================");

    if (conv2_count != CONV2_SIZE) begin
        $display("[FAIL] conv2 count mismatch");
        err_count = err_count + 1;
    end

    if (pool2_count != POOL2_SIZE) begin
        $display("[FAIL] pool2 count mismatch");
        err_count = err_count + 1;
    end

    if (err_count == 0) begin
        $display("==================================================");
        $display("[PASS] Conv1 + Pool1 + Conv2 + Pool2 verification PASS");
        $display("==================================================");
    end
    else begin
        $display("==================================================");
        $display("[FAIL] Conv1 + Pool1 + Conv2 + Pool2 verification FAIL");
        $display("==================================================");
    end
end
endtask

////////////////////////////////////////////////////////////
// Main
////////////////////////////////////////////////////////////
initial begin
    $timeformat(-9, 0, " ns", 10);

    rst = 1'b1;
    start = 1'b0;

    img_wr_en   = 1'b0;
    img_wr_addr = 12'd0;
    img_wr_r    = 16'sd0;
    img_wr_g    = 16'sd0;
    img_wr_b    = 16'sd0;

    conv2_count = 0;
    pool2_count = 0;

    conv2_err_count      = 0;
    pool2_err_count      = 0;
    conv2_meta_err_count = 0;
    pool2_meta_err_count = 0;
    x_err_count          = 0;
    err_count            = 0;

    finish_flag = 1'b0;

    fd_conv2_hex = $fopen({DATA_DIR, "/conv2_hw_out.hex"}, "w");
    fd_conv2_dec = $fopen({DATA_DIR, "/conv2_hw_out_dec.txt"}, "w");
    fd_pool2_hex = $fopen({DATA_DIR, "/pool2_hw_out.hex"}, "w");
    fd_pool2_dec = $fopen({DATA_DIR, "/pool2_hw_out_dec.txt"}, "w");

    if (fd_conv2_hex == 0) begin
        $display("[ERROR] conv2_hw_out.hex open failed");
        $finish;
    end

    if (fd_conv2_dec == 0) begin
        $display("[ERROR] conv2_hw_out_dec.txt open failed");
        $finish;
    end

    if (fd_pool2_hex == 0) begin
        $display("[ERROR] pool2_hw_out.hex open failed");
        $finish;
    end

    if (fd_pool2_dec == 0) begin
        $display("[ERROR] pool2_hw_out_dec.txt open failed");
        $finish;
    end

    $display("==================================================");
    $display("[TB] Load input and expected files");
    $display("==================================================");

    $readmemh({DATA_DIR, "/input_r.hex"}, img_r_mem);
    $readmemh({DATA_DIR, "/input_g.hex"}, img_g_mem);
    $readmemh({DATA_DIR, "/input_b.hex"}, img_b_mem);

    $readmemh({DATA_DIR, "/expected_conv2.hex"}, conv2_ref);
    $readmemh({DATA_DIR, "/expected_pool2.hex"}, pool2_ref);

    $display("[CHECK] input_r[0]=%0d input_g[0]=%0d input_b[0]=%0d",
             img_r_mem[0], img_g_mem[0], img_b_mem[0]);
    $display("[CHECK] expected_conv2[0]=%0d expected_pool2[0]=%0d",
             conv2_ref[0], pool2_ref[0]);

    repeat (20) @(posedge clk);
    rst = 1'b0;
    repeat (10) @(posedge clk);

    ////////////////////////////////////////////////////////////
    // Image write
    ////////////////////////////////////////////////////////////
    $display("==================================================");
    $display("[TB] Write 64x64 RGB image to DUT");
    $display("==================================================");

    for (i = 0; i < IMG_SIZE; i = i + 1) begin
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

    repeat (20) @(posedge clk);

    ////////////////////////////////////////////////////////////
    // Start
    ////////////////////////////////////////////////////////////
    $display("==================================================");
    $display("[TB] Start Conv1 + Pool1 + Conv2 + Pool2");
    $display("==================================================");

    @(posedge clk);
    start <= 1'b1;

    @(posedge clk);
    start <= 1'b0;
end

////////////////////////////////////////////////////////////
// Conv2 output compare
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    #1;

    if (dbg_conv2_valid) begin
        exp_ch  = conv2_count % 64;
        exp_col = (conv2_count / 64) % 29;
        exp_row = conv2_count / (64 * 29);

        if (^dbg_conv2_out === 1'bx) begin
            x_err_count = x_err_count + 1;
            err_count   = err_count + 1;

            if (x_err_count <= 20) begin
                $display("[ERROR] X/Z at Conv2 output count=%0d time=%0t",
                         conv2_count, $time);
            end
        end

        if (conv2_count >= CONV2_SIZE) begin
            conv2_err_count = conv2_err_count + 1;
            err_count       = err_count + 1;

            if (conv2_err_count <= 20) begin
                $display("==================================================");
                $display("[CONV2 OVERFLOW ERROR] count=%0d time=%0t", conv2_count, $time);
                $display("DUT row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                         dbg_conv2_row,
                         dbg_conv2_col,
                         dbg_conv2_ch,
                         dbg_conv2_out,
                         dbg_conv2_out[31:0]);
                $display("==================================================");
            end
        end
        else begin
            if ((dbg_conv2_row !== exp_row[4:0]) ||
                (dbg_conv2_col !== exp_col[4:0]) ||
                (dbg_conv2_ch  !== exp_ch[5:0])) begin

                conv2_meta_err_count = conv2_meta_err_count + 1;
                err_count            = err_count + 1;

                if (conv2_meta_err_count <= 20) begin
                    $display("==================================================");
                    $display("[CONV2 META ERROR] count=%0d time=%0t", conv2_count, $time);
                    $display("EXP row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("DUT row=%0d col=%0d ch=%0d", dbg_conv2_row, dbg_conv2_col, dbg_conv2_ch);
                    $display("==================================================");
                end
            end

            if (dbg_conv2_out !== conv2_ref[conv2_count]) begin
                conv2_err_count = conv2_err_count + 1;
                err_count       = err_count + 1;

                if (conv2_err_count <= 20) begin
                    $display("==================================================");
                    $display("[CONV2 DATA ERROR] count=%0d time=%0t", conv2_count, $time);
                    $display("row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("EXP = %0d / 0x%08h", conv2_ref[conv2_count], conv2_ref[conv2_count]);
                    $display("DUT = %0d / 0x%08h", dbg_conv2_out, dbg_conv2_out[31:0]);
                    $display("==================================================");
                end
            end
        end

        $fdisplay(fd_conv2_hex, "%08h", dbg_conv2_out[31:0]);
        $fdisplay(fd_conv2_dec, "%0d", dbg_conv2_out);

        if ((conv2_count < 10) || (conv2_count >= CONV2_SIZE - 10)) begin
            $display("[CONV2] count=%0d row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                     conv2_count,
                     dbg_conv2_row,
                     dbg_conv2_col,
                     dbg_conv2_ch,
                     dbg_conv2_out,
                     dbg_conv2_out[31:0]);
        end

        conv2_count = conv2_count + 1;
    end
end

////////////////////////////////////////////////////////////
// Pool2 output compare
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    #1;

    if (pool2_valid) begin
        exp_ch  = pool2_count % 64;
        exp_col = (pool2_count / 64) % 14;
        exp_row = pool2_count / (64 * 14);

        if (^pool2_out === 1'bx) begin
            x_err_count = x_err_count + 1;
            err_count   = err_count + 1;

            if (x_err_count <= 20) begin
                $display("[ERROR] X/Z at Pool2 output count=%0d time=%0t",
                         pool2_count, $time);
            end
        end

        if (pool2_count >= POOL2_SIZE) begin
            pool2_err_count = pool2_err_count + 1;
            err_count       = err_count + 1;

            if (pool2_err_count <= 20) begin
                $display("==================================================");
                $display("[POOL2 OVERFLOW ERROR] count=%0d time=%0t", pool2_count, $time);
                $display("DUT row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                         pool2_row,
                         pool2_col,
                         pool2_ch,
                         pool2_out,
                         pool2_out[31:0]);
                $display("==================================================");
            end
        end
        else begin
            if ((pool2_row !== exp_row[3:0]) ||
                (pool2_col !== exp_col[3:0]) ||
                (pool2_ch  !== exp_ch[5:0])) begin

                pool2_meta_err_count = pool2_meta_err_count + 1;
                err_count            = err_count + 1;

                if (pool2_meta_err_count <= 20) begin
                    $display("==================================================");
                    $display("[POOL2 META ERROR] count=%0d time=%0t", pool2_count, $time);
                    $display("EXP row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("DUT row=%0d col=%0d ch=%0d", pool2_row, pool2_col, pool2_ch);
                    $display("==================================================");
                end
            end

            if (pool2_out !== pool2_ref[pool2_count]) begin
                pool2_err_count = pool2_err_count + 1;
                err_count       = err_count + 1;

                if (pool2_err_count <= 20) begin
                    $display("==================================================");
                    $display("[POOL2 DATA ERROR] count=%0d time=%0t", pool2_count, $time);
                    $display("row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("EXP = %0d / 0x%08h", pool2_ref[pool2_count], pool2_ref[pool2_count]);
                    $display("DUT = %0d / 0x%08h", pool2_out, pool2_out[31:0]);
                    $display("==================================================");
                end
            end
        end

        $fdisplay(fd_pool2_hex, "%08h", pool2_out[31:0]);
        $fdisplay(fd_pool2_dec, "%0d", pool2_out);

        if ((pool2_count < 10) || (pool2_count >= POOL2_SIZE - 10)) begin
            $display("[POOL2] count=%0d row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                     pool2_count,
                     pool2_row,
                     pool2_col,
                     pool2_ch,
                     pool2_out,
                     pool2_out[31:0]);
        end

        pool2_count = pool2_count + 1;
    end
end

////////////////////////////////////////////////////////////
// Finish by real output counts
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    #2;

    if ((finish_flag == 1'b0) &&
        (conv2_count == CONV2_SIZE) &&
        (pool2_count == POOL2_SIZE)) begin

        finish_flag = 1'b1;

        repeat (10) @(posedge clk);

        print_summary;
        close_files;

        #100;
        $finish;
    end
end

////////////////////////////////////////////////////////////
// Timeout
////////////////////////////////////////////////////////////
initial begin
    repeat (30000000) @(posedge clk);

    $display("==================================================");
    $display("[TIMEOUT]");
    $display("conv2 count          = %0d / expected %0d", conv2_count, CONV2_SIZE);
    $display("pool2 count          = %0d / expected %0d", pool2_count, POOL2_SIZE);
    $display("conv2 data err count = %0d", conv2_err_count);
    $display("pool2 data err count = %0d", pool2_err_count);
    $display("conv2 meta err count = %0d", conv2_meta_err_count);
    $display("pool2 meta err count = %0d", pool2_meta_err_count);
    $display("x/z err count        = %0d", x_err_count);
    $display("total err count      = %0d", err_count);
    $display("busy                 = %b", busy);
    $display("done                 = %b", done);
    $display("==================================================");

    close_files;

    $finish;
end

endmodule