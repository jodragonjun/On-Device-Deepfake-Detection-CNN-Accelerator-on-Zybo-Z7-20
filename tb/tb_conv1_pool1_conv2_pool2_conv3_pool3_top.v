`timescale 1ns / 1ps

module tb_conv1_pool1_conv2_pool2_conv3_pool3_top;

////////////////////////////////////////////////////////////
// Parameter
////////////////////////////////////////////////////////////
parameter IMG_SIZE   = 4096;      // 64*64
parameter CONV3_SIZE = 18432;     // 12*12*128
parameter POOL3_SIZE = 4608;      // 6*6*128

parameter DATA_DIR = "C:/Xilinx/Vivado/project/capstone/data";

////////////////////////////////////////////////////////////
// Clock / Reset
////////////////////////////////////////////////////////////
reg clk;
reg rst;
reg start;

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;        // 100MHz
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
wire signed [31:0] pool3_out;
wire pool3_valid;
wire [2:0] pool3_row;
wire [2:0] pool3_col;
wire [6:0] pool3_ch;

wire busy;
wire done;

wire signed [31:0] dbg_conv3_out;
wire dbg_conv3_valid;
wire [3:0] dbg_conv3_row;
wire [3:0] dbg_conv3_col;
wire [6:0] dbg_conv3_ch;

////////////////////////////////////////////////////////////
// TB memory
////////////////////////////////////////////////////////////
reg signed [15:0] img_r_mem [0:IMG_SIZE-1];
reg signed [15:0] img_g_mem [0:IMG_SIZE-1];
reg signed [15:0] img_b_mem [0:IMG_SIZE-1];

reg signed [31:0] conv3_ref [0:CONV3_SIZE-1];
reg signed [31:0] pool3_ref [0:POOL3_SIZE-1];

////////////////////////////////////////////////////////////
// Counters
////////////////////////////////////////////////////////////
integer i;

integer conv3_count;
integer pool3_count;

integer conv3_err_count;
integer pool3_err_count;
integer conv3_meta_err_count;
integer pool3_meta_err_count;
integer x_err_count;
integer err_count;

integer exp_row;
integer exp_col;
integer exp_ch;

integer fd_conv3_hex;
integer fd_conv3_dec;
integer fd_pool3_hex;
integer fd_pool3_dec;

////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////
conv1_pool1_conv2_pool2_conv3_pool3_top u_dut (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start),

    .pool3_out(pool3_out),
    .pool3_valid(pool3_valid),
    .pool3_row(pool3_row),
    .pool3_col(pool3_col),
    .pool3_ch(pool3_ch),

    .busy(busy),
    .done(done),

    .dbg_conv3_out(dbg_conv3_out),
    .dbg_conv3_valid(dbg_conv3_valid),
    .dbg_conv3_row(dbg_conv3_row),
    .dbg_conv3_col(dbg_conv3_col),
    .dbg_conv3_ch(dbg_conv3_ch)
);

////////////////////////////////////////////////////////////
// Task: close files
////////////////////////////////////////////////////////////
task close_files;
begin
    if (fd_conv3_hex != 0) $fclose(fd_conv3_hex);
    if (fd_conv3_dec != 0) $fclose(fd_conv3_dec);
    if (fd_pool3_hex != 0) $fclose(fd_pool3_hex);
    if (fd_pool3_dec != 0) $fclose(fd_pool3_dec);
end
endtask

////////////////////////////////////////////////////////////
// Task: print summary
////////////////////////////////////////////////////////////
task print_summary;
begin
    $display("==================================================");
    $display("[TB DONE]");
    $display("conv3 count          = %0d / expected %0d", conv3_count, CONV3_SIZE);
    $display("pool3 count          = %0d / expected %0d", pool3_count, POOL3_SIZE);
    $display("conv3 data err count = %0d", conv3_err_count);
    $display("pool3 data err count = %0d", pool3_err_count);
    $display("conv3 meta err count = %0d", conv3_meta_err_count);
    $display("pool3 meta err count = %0d", pool3_meta_err_count);
    $display("x/z err count        = %0d", x_err_count);
    $display("total err count      = %0d", err_count);
    $display("==================================================");

    if (conv3_count != CONV3_SIZE) begin
        $display("[FAIL] conv3 count mismatch");
        err_count = err_count + 1;
    end

    if (pool3_count != POOL3_SIZE) begin
        $display("[FAIL] pool3 count mismatch");
        err_count = err_count + 1;
    end

    if (err_count == 0) begin
        $display("==================================================");
        $display("[PASS] Conv1 + Pool1 + Conv2 + Pool2 + Conv3 + Pool3 verification PASS");
        $display("==================================================");
    end
    else begin
        $display("==================================================");
        $display("[FAIL] Conv1 + Pool1 + Conv2 + Pool2 + Conv3 + Pool3 verification FAIL");
        $display("==================================================");
    end
end
endtask

////////////////////////////////////////////////////////////
// Main
////////////////////////////////////////////////////////////
initial begin
    rst = 1'b1;
    start = 1'b0;

    img_wr_en   = 1'b0;
    img_wr_addr = 12'd0;
    img_wr_r    = 16'sd0;
    img_wr_g    = 16'sd0;
    img_wr_b    = 16'sd0;

    conv3_count = 0;
    pool3_count = 0;

    conv3_err_count      = 0;
    pool3_err_count      = 0;
    conv3_meta_err_count = 0;
    pool3_meta_err_count = 0;
    x_err_count          = 0;
    err_count            = 0;

    fd_conv3_hex = $fopen("conv3_hw_out.hex", "w");
    fd_conv3_dec = $fopen("conv3_hw_out_dec.txt", "w");
    fd_pool3_hex = $fopen("pool3_hw_out.hex", "w");
    fd_pool3_dec = $fopen("pool3_hw_out_dec.txt", "w");

    if (fd_conv3_hex == 0) begin
        $display("[ERROR] conv3_hw_out.hex open failed");
        $finish;
    end

    if (fd_conv3_dec == 0) begin
        $display("[ERROR] conv3_hw_out_dec.txt open failed");
        $finish;
    end

    if (fd_pool3_hex == 0) begin
        $display("[ERROR] pool3_hw_out.hex open failed");
        $finish;
    end

    if (fd_pool3_dec == 0) begin
        $display("[ERROR] pool3_hw_out_dec.txt open failed");
        $finish;
    end

    $display("==================================================");
    $display("[TB] Load input and expected files");
    $display("==================================================");

    $readmemh({DATA_DIR, "/input_r.hex"}, img_r_mem);
    $readmemh({DATA_DIR, "/input_g.hex"}, img_g_mem);
    $readmemh({DATA_DIR, "/input_b.hex"}, img_b_mem);
    $readmemh({DATA_DIR, "/expected_conv3.hex"}, conv3_ref);
    $readmemh({DATA_DIR, "/expected_pool3.hex"}, pool3_ref);

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
    $display("[TB] Start Conv1 + Pool1 + Conv2 + Pool2 + Conv3 + Pool3");
    $display("==================================================");

    @(posedge clk);
    start <= 1'b1;

    @(posedge clk);
    start <= 1'b0;
end

////////////////////////////////////////////////////////////
// Conv3 output compare
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (dbg_conv3_valid) begin
        exp_ch  = conv3_count % 128;
        exp_col = (conv3_count / 128) % 12;
        exp_row = conv3_count / (128 * 12);

        if (^dbg_conv3_out === 1'bx) begin
            x_err_count = x_err_count + 1;
            err_count   = err_count + 1;

            if (x_err_count <= 20) begin
                $display("[ERROR] X/Z at Conv3 output count=%0d time=%0t",
                         conv3_count, $time);
            end
        end

        if (conv3_count >= CONV3_SIZE) begin
            conv3_err_count = conv3_err_count + 1;
            err_count       = err_count + 1;

            if (conv3_err_count <= 20) begin
                $display("==================================================");
                $display("[CONV3 OVERFLOW ERROR] count=%0d time=%0t", conv3_count, $time);
                $display("DUT row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                         dbg_conv3_row,
                         dbg_conv3_col,
                         dbg_conv3_ch,
                         dbg_conv3_out,
                         dbg_conv3_out[31:0]);
                $display("==================================================");
            end
        end
        else begin
            if ((dbg_conv3_row !== exp_row[3:0]) ||
                (dbg_conv3_col !== exp_col[3:0]) ||
                (dbg_conv3_ch  !== exp_ch[6:0])) begin

                conv3_meta_err_count = conv3_meta_err_count + 1;
                err_count            = err_count + 1;

                if (conv3_meta_err_count <= 20) begin
                    $display("==================================================");
                    $display("[CONV3 META ERROR] count=%0d time=%0t", conv3_count, $time);
                    $display("EXP row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("DUT row=%0d col=%0d ch=%0d", dbg_conv3_row, dbg_conv3_col, dbg_conv3_ch);
                    $display("==================================================");
                end
            end

            if (dbg_conv3_out !== conv3_ref[conv3_count]) begin
                conv3_err_count = conv3_err_count + 1;
                err_count       = err_count + 1;

                if (conv3_err_count <= 20) begin
                    $display("==================================================");
                    $display("[CONV3 DATA ERROR] count=%0d time=%0t", conv3_count, $time);
                    $display("row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("EXP = %0d / 0x%08h", conv3_ref[conv3_count], conv3_ref[conv3_count]);
                    $display("DUT = %0d / 0x%08h", dbg_conv3_out, dbg_conv3_out);
                    $display("==================================================");
                end
            end
        end

        $fdisplay(fd_conv3_hex, "%08h", dbg_conv3_out[31:0]);
        $fdisplay(fd_conv3_dec, "%0d", dbg_conv3_out);

        if ((conv3_count < 10) || (conv3_count >= CONV3_SIZE - 10)) begin
            $display("[CONV3] count=%0d row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                     conv3_count,
                     dbg_conv3_row,
                     dbg_conv3_col,
                     dbg_conv3_ch,
                     dbg_conv3_out,
                     dbg_conv3_out[31:0]);
        end

        conv3_count = conv3_count + 1;
    end
end

////////////////////////////////////////////////////////////
// Pool3 output compare
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (pool3_valid) begin
        exp_ch  = pool3_count % 128;
        exp_col = (pool3_count / 128) % 6;
        exp_row = pool3_count / (128 * 6);

        if (^pool3_out === 1'bx) begin
            x_err_count = x_err_count + 1;
            err_count   = err_count + 1;

            if (x_err_count <= 20) begin
                $display("[ERROR] X/Z at Pool3 output count=%0d time=%0t",
                         pool3_count, $time);
            end
        end

        if (pool3_count >= POOL3_SIZE) begin
            pool3_err_count = pool3_err_count + 1;
            err_count       = err_count + 1;

            if (pool3_err_count <= 20) begin
                $display("==================================================");
                $display("[POOL3 OVERFLOW ERROR] count=%0d time=%0t", pool3_count, $time);
                $display("DUT row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                         pool3_row,
                         pool3_col,
                         pool3_ch,
                         pool3_out,
                         pool3_out[31:0]);
                $display("==================================================");
            end
        end
        else begin
            if ((pool3_row !== exp_row[2:0]) ||
                (pool3_col !== exp_col[2:0]) ||
                (pool3_ch  !== exp_ch[6:0])) begin

                pool3_meta_err_count = pool3_meta_err_count + 1;
                err_count            = err_count + 1;

                if (pool3_meta_err_count <= 20) begin
                    $display("==================================================");
                    $display("[POOL3 META ERROR] count=%0d time=%0t", pool3_count, $time);
                    $display("EXP row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("DUT row=%0d col=%0d ch=%0d", pool3_row, pool3_col, pool3_ch);
                    $display("==================================================");
                end
            end

            if (pool3_out !== pool3_ref[pool3_count]) begin
                pool3_err_count = pool3_err_count + 1;
                err_count       = err_count + 1;

                if (pool3_err_count <= 20) begin
                    $display("==================================================");
                    $display("[POOL3 DATA ERROR] count=%0d time=%0t", pool3_count, $time);
                    $display("row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("EXP = %0d / 0x%08h", pool3_ref[pool3_count], pool3_ref[pool3_count]);
                    $display("DUT = %0d / 0x%08h", pool3_out, pool3_out);
                    $display("==================================================");
                end
            end
        end

        $fdisplay(fd_pool3_hex, "%08h", pool3_out[31:0]);
        $fdisplay(fd_pool3_dec, "%0d", pool3_out);

        if ((pool3_count < 10) || (pool3_count >= POOL3_SIZE - 10)) begin
            $display("[POOL3] count=%0d row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                     pool3_count,
                     pool3_row,
                     pool3_col,
                     pool3_ch,
                     pool3_out,
                     pool3_out[31:0]);
        end

        pool3_count = pool3_count + 1;
    end
end

////////////////////////////////////////////////////////////
// Finish
////////////////////////////////////////////////////////////
initial begin
    wait (done === 1'b1);

    repeat (5) @(posedge clk);

    print_summary;
    close_files;

    #100;
    $finish;
end

////////////////////////////////////////////////////////////
// Timeout
////////////////////////////////////////////////////////////
initial begin
    #1000000000;

    $display("==================================================");
    $display("[TIMEOUT]");
    $display("conv3 count          = %0d / expected %0d", conv3_count, CONV3_SIZE);
    $display("pool3 count          = %0d / expected %0d", pool3_count, POOL3_SIZE);
    $display("conv3 data err count = %0d", conv3_err_count);
    $display("pool3 data err count = %0d", pool3_err_count);
    $display("conv3 meta err count = %0d", conv3_meta_err_count);
    $display("pool3 meta err count = %0d", pool3_meta_err_count);
    $display("x/z err count        = %0d", x_err_count);
    $display("total err count      = %0d", err_count);
    $display("==================================================");

    close_files;

    $finish;
end
////////////////////////////////////////////////////////////
// Conv3 X source debug - safe version
////////////////////////////////////////////////////////////
integer conv3_x_debug_once;

initial begin
    conv3_x_debug_once = 0;
end

always @(posedge clk) begin
    if ((dbg_conv3_valid) && (^dbg_conv3_out === 1'bx) && (conv3_x_debug_once == 0)) begin
        conv3_x_debug_once = 1;

        $display("==================================================");
        $display("[CONV3 X SOURCE DEBUG - SAFE] time=%0t", $time);

        $display("[TOP CONV3 OUTPUT]");
        $display("dbg_conv3_valid = %b", dbg_conv3_valid);
        $display("dbg_conv3_out   = 0x%08h", dbg_conv3_out);
        $display("dbg row=%0d col=%0d ch=%0d",
                 dbg_conv3_row, dbg_conv3_col, dbg_conv3_ch);

        $display("[POOL2 RAM READ]");
        $display("pool2_rd_en   = %b",
                 u_dut.u_conv3_pool2_top.pool2_rd_en);
        $display("pool2_rd_addr = %0d / 0x%04h",
                 u_dut.u_conv3_pool2_top.pool2_rd_addr,
                 u_dut.u_conv3_pool2_top.pool2_rd_addr);
        $display("pool2_rd_data = %0d / 0x%08h",
                 u_dut.u_conv3_pool2_top.pool2_rd_data,
                 u_dut.u_conv3_pool2_top.pool2_rd_data);

        $display("[WINDOW READER]");
        $display("win_valid    = %b",
                 u_dut.u_conv3_pool2_top.win_valid);
        $display("reader_done  = %b",
                 u_dut.u_conv3_pool2_top.reader_done);
        $display("reader_busy  = %b",
                 u_dut.u_conv3_pool2_top.reader_busy);
        $display("reader_in_ch = %0d",
                 u_dut.u_conv3_pool2_top.reader_in_ch);

        $display("p0=0x%08h p1=0x%08h p2=0x%08h",
                 u_dut.u_conv3_pool2_top.p0,
                 u_dut.u_conv3_pool2_top.p1,
                 u_dut.u_conv3_pool2_top.p2);
        $display("p3=0x%08h p4=0x%08h p5=0x%08h",
                 u_dut.u_conv3_pool2_top.p3,
                 u_dut.u_conv3_pool2_top.p4,
                 u_dut.u_conv3_pool2_top.p5);
        $display("p6=0x%08h p7=0x%08h p8=0x%08h",
                 u_dut.u_conv3_pool2_top.p6,
                 u_dut.u_conv3_pool2_top.p7,
                 u_dut.u_conv3_pool2_top.p8);

        $display("[SERIALIZER TO CONV3_CORE]");
        $display("conv3_core_start    = %b",
                 u_dut.u_conv3_pool2_top.conv3_core_start);
        $display("conv3_core_valid_in = %b",
                 u_dut.u_conv3_pool2_top.conv3_core_valid_in);
        $display("conv3_core_in_data  = %0d / 0x%08h",
                 u_dut.u_conv3_pool2_top.conv3_core_in_data,
                 u_dut.u_conv3_pool2_top.conv3_core_in_data);
        $display("conv3_core_in_ch    = %0d",
                 u_dut.u_conv3_pool2_top.conv3_core_in_ch);
        $display("conv3_core_k_idx    = %0d",
                 u_dut.u_conv3_pool2_top.conv3_core_k_idx);

        $display("[CONV3 CONTROL]");
        $display("conv3_core_done = %b",
                 u_dut.u_conv3_pool2_top.conv3_core_done);
        $display("conv3_busy      = %b",
                 u_dut.u_conv3_pool2_top.conv3_busy);
        $display("conv3_done      = %b",
                 u_dut.u_conv3_pool2_top.conv3_done);

        $display("==================================================");
    end
end
endmodule