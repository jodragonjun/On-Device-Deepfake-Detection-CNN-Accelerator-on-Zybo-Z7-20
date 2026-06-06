`timescale 1ns/1ps

module global_avg_pool_6x6_128 (
    clk,
    rst,
    start,

    valid_in,
    in_data,
    in_row,
    in_col,
    in_ch,

    busy,
    valid_out,
    out_data,
    out_ch,
    done
);

input clk;
input rst;
input start;

input valid_in;
input signed [31:0] in_data;
input [2:0] in_row;
input [2:0] in_col;
input [6:0] in_ch;

output reg busy;
output reg valid_out;
output reg signed [63:0] out_data;
output reg [6:0] out_ch;
output reg done;

parameter S_IDLE        = 4'd0;
parameter S_CLEAR       = 4'd1;
parameter S_ACCUM       = 4'd2;
parameter S_ACCUM_DRAIN = 4'd3;
parameter S_OUT_READ    = 4'd4;
parameter S_DIV_START   = 4'd5;
parameter S_DIV_WAIT    = 4'd6;
parameter S_OUT         = 4'd7;
parameter S_DONE        = 4'd8;

reg [3:0] state;

reg [7:0] clear_idx;
reg [7:0] out_idx;
reg [12:0] in_count;

wire signed [63:0] in_ext;
assign in_ext = {{32{in_data[31]}}, in_data};

/*
    128 x 64-bit accumulator memory.

    Important:
    Do not reset this memory inside an async reset block.
    If it is reset with "posedge rst", Vivado dissolves it into FFs and MUXes.
*/
(* ram_style = "block" *) reg signed [63:0] acc_mem [0:127];

reg signed [63:0] mem_rd_data;

wire mem_we;
wire [6:0] mem_wr_addr;
wire signed [63:0] mem_wr_data;
wire [6:0] mem_rd_addr;

/*
    Read-modify-write pipeline.

    Cycle N:
      read acc_mem[in_ch]

    Cycle N+1:
      write acc_mem[in_ch_d1] + in_data_d1
*/
reg acc_valid_d1;
reg signed [63:0] acc_data_d1;
reg [6:0] acc_ch_d1;

/*
    Bypass for same-address consecutive accumulation.
*/
reg last_wr_valid;
reg [6:0] last_wr_addr;
reg signed [63:0] last_wr_data;

wire signed [63:0] accum_base;
wire signed [63:0] accum_sum;

assign accum_base = (last_wr_valid && (last_wr_addr == acc_ch_d1)) ?
                    last_wr_data :
                    mem_rd_data;

assign accum_sum = accum_base + acc_data_d1;

assign mem_we = (state == S_CLEAR) ||
                (((state == S_ACCUM) || (state == S_ACCUM_DRAIN)) && acc_valid_d1);

assign mem_wr_addr = (state == S_CLEAR) ?
                     clear_idx[6:0] :
                     acc_ch_d1;

assign mem_wr_data = (state == S_CLEAR) ?
                     64'sd0 :
                     accum_sum;

assign mem_rd_addr = (state == S_ACCUM) ?
                     in_ch :
                     ((state == S_OUT_READ) ? out_idx[6:0] : 7'd0);

/*
    RAM block.
    No asynchronous reset here.
*/
always @(posedge clk) begin
    if (mem_we) begin
        acc_mem[mem_wr_addr] <= mem_wr_data;
    end

    mem_rd_data <= acc_mem[mem_rd_addr];
end

reg div_start;
reg signed [63:0] div_in;
wire div_busy;
wire div_done;
wire signed [63:0] div_q;

signed_div_const36_seq u_div36 (
    .clk(clk),
    .rst(rst),
    .start(div_start),
    .dividend(div_in),
    .busy(div_busy),
    .done(div_done),
    .quotient(div_q)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;

        busy <= 1'b0;
        valid_out <= 1'b0;
        out_data <= 64'sd0;
        out_ch <= 7'd0;
        done <= 1'b0;

        clear_idx <= 8'd0;
        out_idx <= 8'd0;
        in_count <= 13'd0;

        acc_valid_d1 <= 1'b0;
        acc_data_d1 <= 64'sd0;
        acc_ch_d1 <= 7'd0;

        last_wr_valid <= 1'b0;
        last_wr_addr <= 7'd0;
        last_wr_data <= 64'sd0;

        div_start <= 1'b0;
        div_in <= 64'sd0;
    end
    else begin
        valid_out <= 1'b0;
        div_start <= 1'b0;

        last_wr_valid <= mem_we;

        if (mem_we) begin
            last_wr_addr <= mem_wr_addr;
            last_wr_data <= mem_wr_data;
        end

        case (state)

            S_IDLE: begin
                busy <= 1'b0;
                done <= 1'b0;
                acc_valid_d1 <= 1'b0;

                if (start) begin
                    busy <= 1'b1;
                    clear_idx <= 8'd0;
                    state <= S_CLEAR;
                end
            end

            S_CLEAR: begin
                acc_valid_d1 <= 1'b0;

                if (clear_idx == 8'd127) begin
                    in_count <= 13'd0;
                    state <= S_ACCUM;
                end
                else begin
                    clear_idx <= clear_idx + 8'd1;
                end
            end

            S_ACCUM: begin
                acc_valid_d1 <= valid_in;

                if (valid_in) begin
                    acc_data_d1 <= in_ext;
                    acc_ch_d1 <= in_ch;

                    if (in_count == 13'd4607) begin
                        out_idx <= 8'd0;
                        state <= S_ACCUM_DRAIN;
                    end
                    else begin
                        in_count <= in_count + 13'd1;
                    end
                end
            end

            S_ACCUM_DRAIN: begin
                acc_valid_d1 <= 1'b0;
                state <= S_OUT_READ;
            end

            S_OUT_READ: begin
                state <= S_DIV_START;
            end

            S_DIV_START: begin
                div_in <= mem_rd_data;
                div_start <= 1'b1;
                state <= S_DIV_WAIT;
            end

            S_DIV_WAIT: begin
                if (div_done) begin
                    state <= S_OUT;
                end
            end

            S_OUT: begin
                valid_out <= 1'b1;
                out_ch <= out_idx[6:0];
                out_data <= div_q;

                if (out_idx == 8'd127) begin
                    done <= 1'b1;
                    state <= S_DONE;
                end
                else begin
                    out_idx <= out_idx + 8'd1;
                    state <= S_OUT_READ;
                end
            end

            S_DONE: begin
                busy <= 1'b0;

                if (start) begin
                    done <= 1'b0;
                    busy <= 1'b1;
                    clear_idx <= 8'd0;
                    state <= S_CLEAR;
                end
            end

            default: begin
                state <= S_IDLE;
            end

        endcase
    end
end

endmodule