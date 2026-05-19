`timescale 1ns/1ps

module tb_conv1_top;

////////////////////////////////////////////////////////////
// Parameter
////////////////////////////////////////////////////////////
parameter IMG_SIZE = 4096;   // 64*64
parameter W_SIZE   = 864;    // 32*3*9
parameter B_SIZE   = 32;

////////////////////////////////////////////////////////////
// Clock / Reset
////////////////////////////////////////////////////////////
reg clk;
reg rst;
reg start;

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;   // 100MHz
end

////////////////////////////////////////////////////////////
// DUT input window
////////////////////////////////////////////////////////////
reg signed [15:0] r00, r01, r02;
reg signed [15:0] r10, r11, r12;
reg signed [15:0] r20, r21, r22;

reg signed [15:0] g00, g01, g02;
reg signed [15:0] g10, g11, g12;
reg signed [15:0] g20, g21, g22;

reg signed [15:0] b00, b01, b02;
reg signed [15:0] b10, b11, b12;
reg signed [15:0] b20, b21, b22;

////////////////////////////////////////////////////////////
// DUT output
////////////////////////////////////////////////////////////
wire signed [31:0] out;
wire valid_out;
wire done;

////////////////////////////////////////////////////////////
// TB memory
////////////////////////////////////////////////////////////
reg signed [15:0] img_r_mem [0:IMG_SIZE-1];
reg signed [15:0] img_g_mem [0:IMG_SIZE-1];
reg signed [15:0] img_b_mem [0:IMG_SIZE-1];

reg signed [15:0] w_mem    [0:W_SIZE-1];
reg signed [15:0] bias_mem [0:B_SIZE-1];

reg signed [31:0] exp_ref [0:31];

////////////////////////////////////////////////////////////
// TB variables
////////////////////////////////////////////////////////////
integer i;
integer oc;
integer ic;
integer base_k;
integer addr;

integer out_count;
integer err_count;
integer x_err_count;

integer fd_out;

reg signed [31:0] ref_acc;
reg signed [31:0] ref_sum;
reg signed [31:0] ref_p0;
reg signed [31:0] ref_p1;
reg signed [31:0] ref_p2;
reg signed [31:0] ref_p3;

////////////////////////////////////////////////////////////
// Function: sign extension 16 -> 32
////////////////////////////////////////////////////////////
function signed [31:0] sx16_to_32;
    input signed [15:0] din;
    begin
        sx16_to_32 = {{16{din[15]}}, din};
    end
endfunction

////////////////////////////////////////////////////////////
// Function: PE behavior
// DUT pe:
//     mult <= a * b;
//     out  <= mult >>> 8;
////////////////////////////////////////////////////////////
function signed [31:0] pe_mul_shift;
    input signed [15:0] aa;
    input signed [15:0] bb;

    reg signed [31:0] mult_tmp;

    begin
        mult_tmp     = aa * bb;
        pe_mul_shift = mult_tmp >>> 8;
    end
endfunction

////////////////////////////////////////////////////////////
// Function: pixel select
////////////////////////////////////////////////////////////
function signed [15:0] get_pix;
    input [1:0] ch;
    input [3:0] kk;

    begin
        get_pix = 16'sd0;

        if (ch == 2'd0) begin
            case (kk)
                4'd0: get_pix = r00;
                4'd1: get_pix = r01;
                4'd2: get_pix = r02;
                4'd3: get_pix = r10;
                4'd4: get_pix = r11;
                4'd5: get_pix = r12;
                4'd6: get_pix = r20;
                4'd7: get_pix = r21;
                4'd8: get_pix = r22;
                default: get_pix = 16'sd0;
            endcase
        end
        else if (ch == 2'd1) begin
            case (kk)
                4'd0: get_pix = g00;
                4'd1: get_pix = g01;
                4'd2: get_pix = g02;
                4'd3: get_pix = g10;
                4'd4: get_pix = g11;
                4'd5: get_pix = g12;
                4'd6: get_pix = g20;
                4'd7: get_pix = g21;
                4'd8: get_pix = g22;
                default: get_pix = 16'sd0;
            endcase
        end
        else begin
            case (kk)
                4'd0: get_pix = b00;
                4'd1: get_pix = b01;
                4'd2: get_pix = b02;
                4'd3: get_pix = b10;
                4'd4: get_pix = b11;
                4'd5: get_pix = b12;
                4'd6: get_pix = b20;
                4'd7: get_pix = b21;
                4'd8: get_pix = b22;
                default: get_pix = 16'sd0;
            endcase
        end
    end
endfunction

////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////
conv1_top u_dut (
    .clk(clk),
    .rst(rst),
    .start(start),

    .r00(r00), .r01(r01), .r02(r02),
    .r10(r10), .r11(r11), .r12(r12),
    .r20(r20), .r21(r21), .r22(r22),

    .g00(g00), .g01(g01), .g02(g02),
    .g10(g10), .g11(g11), .g12(g12),
    .g20(g20), .g21(g21), .g22(g22),

    .b00(b00), .b01(b01), .b02(b02),
    .b10(b10), .b11(b11), .b12(b12),
    .b20(b20), .b21(b21), .b22(b22),

    .out(out),
    .valid_out(valid_out),
    .done(done)
);

////////////////////////////////////////////////////////////
// Main
////////////////////////////////////////////////////////////
initial begin
    $timeformat(-9, 0, " ns", 10);

    rst   = 1'b1;
    start = 1'b0;

    r00 = 16'sd0; r01 = 16'sd0; r02 = 16'sd0;
    r10 = 16'sd0; r11 = 16'sd0; r12 = 16'sd0;
    r20 = 16'sd0; r21 = 16'sd0; r22 = 16'sd0;

    g00 = 16'sd0; g01 = 16'sd0; g02 = 16'sd0;
    g10 = 16'sd0; g11 = 16'sd0; g12 = 16'sd0;
    g20 = 16'sd0; g21 = 16'sd0; g22 = 16'sd0;

    b00 = 16'sd0; b01 = 16'sd0; b02 = 16'sd0;
    b10 = 16'sd0; b11 = 16'sd0; b12 = 16'sd0;
    b20 = 16'sd0; b21 = 16'sd0; b22 = 16'sd0;

    out_count   = 0;
    err_count   = 0;
    x_err_count = 0;

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

    for (i = 0; i < 32; i = i + 1) begin
        exp_ref[i] = 32'sd0;
    end

    fd_out = $fopen("C:/Xilinx/Vivado/project/capstone/data/conv1_single_hw_out.txt", "w");

    if (fd_out == 0) begin
        $display("[ERROR] output file open failed");
        $finish;
    end

    ////////////////////////////////////////////////////////////
    // Load files
    ////////////////////////////////////////////////////////////
    $display("==================================================");
    $display("[TB] Load input / weight / bias files");
    $display("==================================================");

    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_r.hex", img_r_mem);
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_g.hex", img_g_mem);
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/input_b.hex", img_b_mem);

    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv1_weight.hex", w_mem);
    $readmemh("C:/Xilinx/Vivado/project/capstone/data/conv1_bias.hex", bias_mem);

    $display("[CHECK] input_r[0]=%0d input_g[0]=%0d input_b[0]=%0d",
             img_r_mem[0], img_g_mem[0], img_b_mem[0]);
    $display("[CHECK] conv1_weight[0]=%0d conv1_bias[0]=%0d",
             w_mem[0], bias_mem[0]);

    ////////////////////////////////////////////////////////////
    // First 3x3 RGB window: row=0, col=0
    ////////////////////////////////////////////////////////////
    r00 = img_r_mem[0];
    r01 = img_r_mem[1];
    r02 = img_r_mem[2];
    r10 = img_r_mem[64];
    r11 = img_r_mem[65];
    r12 = img_r_mem[66];
    r20 = img_r_mem[128];
    r21 = img_r_mem[129];
    r22 = img_r_mem[130];

    g00 = img_g_mem[0];
    g01 = img_g_mem[1];
    g02 = img_g_mem[2];
    g10 = img_g_mem[64];
    g11 = img_g_mem[65];
    g12 = img_g_mem[66];
    g20 = img_g_mem[128];
    g21 = img_g_mem[129];
    g22 = img_g_mem[130];

    b00 = img_b_mem[0];
    b01 = img_b_mem[1];
    b02 = img_b_mem[2];
    b10 = img_b_mem[64];
    b11 = img_b_mem[65];
    b12 = img_b_mem[66];
    b20 = img_b_mem[128];
    b21 = img_b_mem[129];
    b22 = img_b_mem[130];

    ////////////////////////////////////////////////////////////
    // Expected Conv1 calculation
    //
    // DUT behavior:
    //   PE output = (pixel * weight) >>> 8
    //   ACC       = sum of PE outputs
    //   BIAS      = ACC + bias
    //   OUT       = ReLU(BIAS)
    //
    // 4-lane grouping:
    //   k=0 : 0,1,2,3
    //   k=4 : 4,5,6,7
    //   k=8 : 8 only
    ////////////////////////////////////////////////////////////
    for (oc = 0; oc < 32; oc = oc + 1) begin
        ref_acc = 32'sd0;

        for (ic = 0; ic < 3; ic = ic + 1) begin
            for (base_k = 0; base_k < 9; base_k = base_k + 4) begin
                addr = oc * 27 + ic * 9 + base_k;

                ref_p0 = pe_mul_shift(get_pix(ic[1:0], base_k[3:0]), w_mem[addr]);

                if (base_k == 8) begin
                    ref_p1 = 32'sd0;
                    ref_p2 = 32'sd0;
                    ref_p3 = 32'sd0;
                end
                else begin
                    ref_p1 = pe_mul_shift(get_pix(ic[1:0], (base_k + 1)), w_mem[addr + 1]);
                    ref_p2 = pe_mul_shift(get_pix(ic[1:0], (base_k + 2)), w_mem[addr + 2]);
                    ref_p3 = pe_mul_shift(get_pix(ic[1:0], (base_k + 3)), w_mem[addr + 3]);
                end

                ref_sum = ref_p0 + ref_p1 + ref_p2 + ref_p3;
                ref_acc = ref_acc + ref_sum;
            end
        end

        ref_acc = ref_acc + sx16_to_32(bias_mem[oc]);

        if (ref_acc < 0) begin
            exp_ref[oc] = 32'sd0;
        end
        else begin
            exp_ref[oc] = ref_acc;
        end

        $display("[EXP] ch=%0d expected=%0d hex=%08h",
                 oc, exp_ref[oc], exp_ref[oc]);
    end

    ////////////////////////////////////////////////////////////
    // Reset release and start
    ////////////////////////////////////////////////////////////
    repeat (10) @(posedge clk);
    rst = 1'b0;

    repeat (5) @(posedge clk);

    $display("==================================================");
    $display("[TB] Start Conv1 single-window test");
    $display("==================================================");

    @(posedge clk);
    start <= 1'b1;

    @(posedge clk);
    start <= 1'b0;
end

////////////////////////////////////////////////////////////
// Output compare
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (valid_out) begin
        if (out_count >= 32) begin
            err_count = err_count + 1;

            $display("==================================================");
            $display("[ERROR] Too many outputs");
            $display("time=%0t out_count=%0d out=%0d hex=%08h",
                     $time, out_count, out, out[31:0]);
            $display("==================================================");
        end
        else begin
            if (^out === 1'bx) begin
                x_err_count = x_err_count + 1;
                err_count   = err_count + 1;

                $display("==================================================");
                $display("[ERROR] X/Z output detected");
                $display("time=%0t out_count=%0d out=%h", $time, out_count, out);
                $display("DUT debug: w0=%h w1=%h w2=%h w3=%h bias=%h bias_reg=%h",
                         u_dut.w0, u_dut.w1, u_dut.w2, u_dut.w3,
                         u_dut.bias, u_dut.bias_reg);
                $display("DUT debug: acc_out=%h acc_valid=%b relu_in_reg=%h",
                         u_dut.acc_out, u_dut.acc_valid, u_dut.relu_in_reg);
                $display("==================================================");
            end
            else if (out !== exp_ref[out_count]) begin
                err_count = err_count + 1;

                $display("==================================================");
                $display("[DATA ERROR] ch=%0d time=%0t", out_count, $time);
                $display("EXP = %0d / 0x%08h", exp_ref[out_count], exp_ref[out_count]);
                $display("DUT = %0d / 0x%08h", out, out[31:0]);
                $display("DUT debug: acc_out=%0d bias_reg=%0d relu_in_reg=%0d",
                         u_dut.acc_out, u_dut.bias_reg, u_dut.relu_in_reg);
                $display("==================================================");
            end
            else begin
                $display("[PASS CH] ch=%0d out=%0d hex=%08h",
                         out_count, out, out[31:0]);
            end

            $fdisplay(fd_out, "%0d %08h", out, out[31:0]);
        end

        out_count = out_count + 1;
    end
end

////////////////////////////////////////////////////////////
// Finish
////////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (done) begin
        $display("==================================================");
        $display("[TB DONE]");
        $display("out_count   = %0d / expected 32", out_count);
        $display("x_err_count = %0d", x_err_count);
        $display("err_count   = %0d", err_count);
        $display("==================================================");

        if (out_count != 32) begin
            $display("[FAIL] output count mismatch");
            err_count = err_count + 1;
        end

        if (err_count == 0) begin
            $display("==================================================");
            $display("[PASS] Conv1 single-window verification PASS");
            $display("==================================================");
        end
        else begin
            $display("==================================================");
            $display("[FAIL] Conv1 single-window verification FAIL");
            $display("==================================================");
        end

        $fclose(fd_out);

        #100;
        $finish;
    end
end

////////////////////////////////////////////////////////////
// Timeout
////////////////////////////////////////////////////////////
initial begin
    repeat (10000) @(posedge clk);

    $display("==================================================");
    $display("[TIMEOUT]");
    $display("out_count   = %0d / expected 32", out_count);
    $display("x_err_count = %0d", x_err_count);
    $display("err_count   = %0d", err_count);
    $display("DUT state debug: valid_out=%b done=%b", valid_out, done);
    $display("==================================================");

    $fclose(fd_out);
    $finish;
end

endmodule