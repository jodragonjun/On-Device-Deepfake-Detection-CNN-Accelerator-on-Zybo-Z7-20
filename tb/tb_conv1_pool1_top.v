`timescale 1ns/1ps

module tb_conv1_pool1_top;

////////////////////////////////////////////////////////////
// Parameter
////////////////////////////////////////////////////////////
parameter IMG_SIZE        = 4096;       // 64*64
parameter W_SIZE          = 864;        // 32*3*9
parameter B_SIZE          = 32;
parameter POOL_OUT_TOTAL  = 30752;      // 31*31*32

parameter DATA_DIR = "C:/Xilinx/Vivado/project/capstone/data";

////////////////////////////////////////////////////////////
// Clock / Reset
////////////////////////////////////////////////////////////
reg clk;
reg rst;
reg start;

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;              // 100MHz
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
wire signed [31:0] pool_out;
wire pool_valid;
wire [4:0] pool_row;
wire [4:0] pool_col;
wire [5:0] pool_ch;

wire busy;
wire done;

////////////////////////////////////////////////////////////
// TB memory
////////////////////////////////////////////////////////////
reg signed [15:0] img_r_mem [0:IMG_SIZE-1];
reg signed [15:0] img_g_mem [0:IMG_SIZE-1];
reg signed [15:0] img_b_mem [0:IMG_SIZE-1];

reg signed [15:0] w_mem    [0:W_SIZE-1];
reg signed [15:0] bias_mem [0:B_SIZE-1];

////////////////////////////////////////////////////////////
// TB variables
////////////////////////////////////////////////////////////
integer i;

integer pool_count;
integer err_count;
integer data_err_count;
integer meta_err_count;
integer x_err_count;

integer exp_row;
integer exp_col;
integer exp_ch;

integer fd_pool_hex;
integer fd_pool_dec;

reg signed [31:0] exp_pool;

////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////
conv1_pool1_top u_dut (
    .clk(clk),
    .rst(rst),

    .img_wr_en(img_wr_en),
    .img_wr_addr(img_wr_addr),
    .img_wr_r(img_wr_r),
    .img_wr_g(img_wr_g),
    .img_wr_b(img_wr_b),

    .start(start),

    .busy(busy),
    .done(done),

    .pool_out(pool_out),
    .pool_valid(pool_valid),
    .pool_row(pool_row),
    .pool_col(pool_col),
    .pool_ch(pool_ch)
);

////////////////////////////////////////////////////////////
// Function: signed 32-bit wrap
////////////////////////////////////////////////////////////
function signed [31:0] s32;
    input signed [63:0] value;
    begin
        s32 = value[31:0];
    end
endfunction

////////////////////////////////////////////////////////////
// Function: PE behavior
// DUT pe:
//     mult <= a * b;
//     out  <= mult >>> 8;
////////////////////////////////////////////////////////////
function signed [31:0] pe16x16_q8;
    input signed [15:0] a;
    input signed [15:0] b;

    reg signed [31:0] mult_tmp;

    begin
        mult_tmp   = a * b;
        pe16x16_q8 = mult_tmp >>> 8;
    end
endfunction

////////////////////////////////////////////////////////////
// Function: get image pixel
// ch = 0:R, 1:G, 2:B
////////////////////////////////////////////////////////////
function signed [15:0] get_img_pixel;
    input integer ch;
    input integer row;
    input integer col;

    integer idx;

    begin
        idx = row * 64 + col;

        if (ch == 0) begin
            get_img_pixel = img_r_mem[idx];
        end
        else if (ch == 1) begin
            get_img_pixel = img_g_mem[idx];
        end
        else begin
            get_img_pixel = img_b_mem[idx];
        end
    end
endfunction

////////////////////////////////////////////////////////////
// Function: calculate Conv1 output
// input  : 64x64x3
// output : 62x62x32
// order  : out_ch -> in_ch -> kernel
////////////////////////////////////////////////////////////
function signed [31:0] calc_conv1;
    input integer out_ch;
    input integer row;
    input integer col;

    integer in_ch;
    integer base_k;
    integer k;
    integer lane;
    integer addr;

    reg signed [31:0] acc;
    reg signed [31:0] group_sum;
    reg signed [31:0] pe_out;

    reg signed [15:0] pix;
    reg signed [15:0] wt;

    begin
        acc = 32'sd0;

        for (in_ch = 0; in_ch < 3; in_ch = in_ch + 1) begin
            for (base_k = 0; base_k < 9; base_k = base_k + 4) begin
                group_sum = 32'sd0;

                for (lane = 0; lane < 4; lane = lane + 1) begin
                    k = base_k + lane;

                    if (k < 9) begin
                        case (k)
                            0: pix = get_img_pixel(in_ch, row + 0, col + 0);
                            1: pix = get_img_pixel(in_ch, row + 0, col + 1);
                            2: pix = get_img_pixel(in_ch, row + 0, col + 2);
                            3: pix = get_img_pixel(in_ch, row + 1, col + 0);
                            4: pix = get_img_pixel(in_ch, row + 1, col + 1);
                            5: pix = get_img_pixel(in_ch, row + 1, col + 2);
                            6: pix = get_img_pixel(in_ch, row + 2, col + 0);
                            7: pix = get_img_pixel(in_ch, row + 2, col + 1);
                            8: pix = get_img_pixel(in_ch, row + 2, col + 2);
                            default: pix = 16'sd0;
                        endcase

                        addr = out_ch * 27 + in_ch * 9 + k;
                        wt   = w_mem[addr];

                        pe_out    = pe16x16_q8(pix, wt);
                        group_sum = s32(group_sum + pe_out);
                    end
                end

                acc = s32(acc + group_sum);
            end
        end

        acc = s32(acc + {{16{bias_mem[out_ch][15]}}, bias_mem[out_ch]});

        if (acc < 0) begin
            calc_conv1 = 32'sd0;
        end
        else begin
            calc_conv1 = acc;
        end
    end
endfunction

////////////////////////////////////////////////////////////
// Function: calculate Pool1 output
// input  : 62x62x32
// output : 31x31x32
////////////////////////////////////////////////////////////
function signed [31:0] calc_pool1;
    input integer ch;
    input integer row;
    input integer col;

    integer r;
    integer c;

    reg signed [31:0] v00;
    reg signed [31:0] v01;
    reg signed [31:0] v10;
    reg signed [31:0] v11;
    reg signed [31:0] max0;
    reg signed [31:0] max1;
    reg signed [31:0] max2;

    begin
        r = row * 2;
        c = col * 2;

        v00 = calc_conv1(ch, r + 0, c + 0);
        v01 = calc_conv1(ch, r + 0, c + 1);
        v10 = calc_conv1(ch, r + 1, c + 0);
        v11 = calc_conv1(ch, r + 1, c + 1);

        if (v00 >= v01) begin
            max0 = v00;
        end
        else begin
            max0 = v01;
        end

        if (v10 >= v11) begin
            max1 = v10;
        end
        else begin
            max1 = v11;
        end

        if (max0 >= max1) begin
            max2 = max0;
        end
        else begin
            max2 = max1;
        end

        calc_pool1 = max2;
    end
endfunction

////////////////////////////////////////////////////////////
// Main
////////////////////////////////////////////////////////////
initial begin
    $timeformat(-9, 0, " ns", 10);

    rst   = 1'b1;
    start = 1'b0;

    img_wr_en   = 1'b0;
    img_wr_addr = 12'd0;
    img_wr_r    = 16'sd0;
    img_wr_g    = 16'sd0;
    img_wr_b    = 16'sd0;

    pool_count    = 0;
    err_count     = 0;
    data_err_count = 0;
    meta_err_count = 0;
    x_err_count    = 0;

    for (i = 0; i < IMG_SIZE; i = i + 1) begin
        img_r_mem[i] = 16'sd0;
        img_g_mem[i] = 16'sd0;
        img_b_mem[i] = 16'sd0;
    end

    for (i = 0; i < W_SIZE; i = i + 1) begin
        w_mem[i] = 16'sd0;
    end

    for (i = 0; i < B_SIZE; i = i + 1) begin
        bias_mem[i] = 16'sd0;
    end

    fd_pool_hex = $fopen({DATA_DIR, "/pool1_hw_out.hex"}, "w");
    fd_pool_dec = $fopen({DATA_DIR, "/pool1_hw_out_dec.txt"}, "w");

    if (fd_pool_hex == 0) begin
        $display("[ERROR] pool1_hw_out.hex open failed");
        $finish;
    end

    if (fd_pool_dec == 0) begin
        $display("[ERROR] pool1_hw_out_dec.txt open failed");
        $finish;
    end

    $display("==================================================");
    $display("[TB] Load input / weight / bias files");
    $display("==================================================");

    $readmemh({DATA_DIR, "/input_r.hex"}, img_r_mem);
    $readmemh({DATA_DIR, "/input_g.hex"}, img_g_mem);
    $readmemh({DATA_DIR, "/input_b.hex"}, img_b_mem);

    $readmemh({DATA_DIR, "/conv1_weight.hex"}, w_mem);
    $readmemh({DATA_DIR, "/conv1_bias.hex"}, bias_mem);

    $display("[CHECK] input_r[0]=%0d input_g[0]=%0d input_b[0]=%0d",
             img_r_mem[0], img_g_mem[0], img_b_mem[0]);
    $display("[CHECK] conv1_weight[0]=%0d conv1_bias[0]=%0d",
             w_mem[0], bias_mem[0]);

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
    $display("[TB] Start Conv1 + Pool1");
    $display("==================================================");

    @(posedge clk);
    start <= 1'b1;

    @(posedge clk);
    start <= 1'b0;
end

////////////////////////////////////////////////////////////
// Pool1 output compare
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (pool_valid) begin
        exp_ch  = pool_count % 32;
        exp_col = (pool_count / 32) % 31;
        exp_row = pool_count / (32 * 31);

        if (^pool_out === 1'bx) begin
            x_err_count = x_err_count + 1;
            err_count   = err_count + 1;

            if (x_err_count <= 20) begin
                $display("[ERROR] X/Z at Pool1 output count=%0d time=%0t",
                         pool_count, $time);
            end
        end

        if (pool_count >= POOL_OUT_TOTAL) begin
            data_err_count = data_err_count + 1;
            err_count      = err_count + 1;

            if (data_err_count <= 20) begin
                $display("==================================================");
                $display("[POOL1 OVERFLOW ERROR] count=%0d time=%0t", pool_count, $time);
                $display("DUT row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                         pool_row, pool_col, pool_ch, pool_out, pool_out[31:0]);
                $display("==================================================");
            end
        end
        else begin
            exp_pool = calc_pool1(exp_ch, exp_row, exp_col);

            if ((pool_row !== exp_row[4:0]) ||
                (pool_col !== exp_col[4:0]) ||
                (pool_ch  !== exp_ch[5:0])) begin

                meta_err_count = meta_err_count + 1;
                err_count      = err_count + 1;

                if (meta_err_count <= 20) begin
                    $display("==================================================");
                    $display("[POOL1 META ERROR] count=%0d time=%0t", pool_count, $time);
                    $display("EXP row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("DUT row=%0d col=%0d ch=%0d", pool_row, pool_col, pool_ch);
                    $display("==================================================");
                end
            end

            if (pool_out !== exp_pool) begin
                data_err_count = data_err_count + 1;
                err_count      = err_count + 1;

                if (data_err_count <= 20) begin
                    $display("==================================================");
                    $display("[POOL1 DATA ERROR] count=%0d time=%0t", pool_count, $time);
                    $display("row=%0d col=%0d ch=%0d", exp_row, exp_col, exp_ch);
                    $display("EXP = %0d / 0x%08h", exp_pool, exp_pool[31:0]);
                    $display("DUT = %0d / 0x%08h", pool_out, pool_out[31:0]);
                    $display("==================================================");
                end
            end
            else begin
                if ((pool_count < 10) || (pool_count >= POOL_OUT_TOTAL - 10)) begin
                    $display("[POOL1 PASS] count=%0d row=%0d col=%0d ch=%0d data=%0d hex=%08h",
                             pool_count, pool_row, pool_col, pool_ch,
                             pool_out, pool_out[31:0]);
                end
            end
        end

        $fdisplay(fd_pool_hex, "%08h", pool_out[31:0]);
        $fdisplay(fd_pool_dec, "%0d", pool_out);

        pool_count = pool_count + 1;
    end
end

////////////////////////////////////////////////////////////
// Finish
////////////////////////////////////////////////////////////
initial begin
    wait (done === 1'b1);

    repeat (5) @(posedge clk);

    $display("==================================================");
    $display("[TB DONE]");
    $display("pool1 count          = %0d / expected %0d", pool_count, POOL_OUT_TOTAL);
    $display("pool1 data err count = %0d", data_err_count);
    $display("pool1 meta err count = %0d", meta_err_count);
    $display("x/z err count        = %0d", x_err_count);
    $display("total err count      = %0d", err_count);
    $display("==================================================");

    if (pool_count != POOL_OUT_TOTAL) begin
        $display("[FAIL] pool1 count mismatch");
        err_count = err_count + 1;
    end

    if (err_count == 0) begin
        $display("==================================================");
        $display("[PASS] Conv1 + Pool1 verification PASS");
        $display("==================================================");
    end
    else begin
        $display("==================================================");
        $display("[FAIL] Conv1 + Pool1 verification FAIL");
        $display("==================================================");
    end

    $fclose(fd_pool_hex);
    $fclose(fd_pool_dec);

    #100;
    $finish;
end

////////////////////////////////////////////////////////////
// Timeout
////////////////////////////////////////////////////////////
initial begin
    repeat (5000000) @(posedge clk);

    $display("==================================================");
    $display("[TIMEOUT]");
    $display("pool1 count          = %0d / expected %0d", pool_count, POOL_OUT_TOTAL);
    $display("pool1 data err count = %0d", data_err_count);
    $display("pool1 meta err count = %0d", meta_err_count);
    $display("x/z err count        = %0d", x_err_count);
    $display("total err count      = %0d", err_count);
    $display("busy=%b done=%b pool_valid=%b", busy, done, pool_valid);
    $display("==================================================");

    $fclose(fd_pool_hex);
    $fclose(fd_pool_dec);

    $finish;
end

endmodule