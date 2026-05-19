`timescale 1ns/1ps

module pool2_window_reader (
    clk,
    rst,
    start,

    req_row,
    req_col,

    mem_dout,
    mem_addr,
    mem_rd_en,

    valid_out,
    done,
    busy,

    out_row,
    out_col,
    in_ch,

    p0, p1, p2,
    p3, p4, p5,
    p6, p7, p8,

    last_in_ch
);

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 14;

input clk;
input rst;
input start;

input [3:0] req_row;   // 0~11
input [3:0] req_col;   // 0~11

input signed [DATA_WIDTH-1:0] mem_dout;
output reg [ADDR_WIDTH-1:0] mem_addr;
output reg mem_rd_en;

output reg valid_out;
output reg done;
output reg busy;

output reg [3:0] out_row;
output reg [3:0] out_col;
output reg [5:0] in_ch;      // 0~63

output reg signed [DATA_WIDTH-1:0] p0;
output reg signed [DATA_WIDTH-1:0] p1;
output reg signed [DATA_WIDTH-1:0] p2;
output reg signed [DATA_WIDTH-1:0] p3;
output reg signed [DATA_WIDTH-1:0] p4;
output reg signed [DATA_WIDTH-1:0] p5;
output reg signed [DATA_WIDTH-1:0] p6;
output reg signed [DATA_WIDTH-1:0] p7;
output reg signed [DATA_WIDTH-1:0] p8;

output last_in_ch;

reg [2:0] state;
reg [3:0] read_idx;

parameter S_IDLE = 3'd0;
parameter S_ADDR = 3'd1;
parameter S_WAIT = 3'd2;
parameter S_CAP  = 3'd3;
parameter S_OUT  = 3'd4;
parameter S_NEXT = 3'd5;

assign last_in_ch = valid_out & (in_ch == 6'd63);

function [ADDR_WIDTH-1:0] calc_addr;
    input [5:0] ch;
    input [4:0] r;
    input [4:0] c;

    reg [15:0] ch_base;
    reg [15:0] row_base;
    reg [15:0] temp_addr;

    begin
        // ch * 196 = ch * (128 + 64 + 4)
        ch_base = ({10'd0, ch} << 7) + ({10'd0, ch} << 6) + ({10'd0, ch} << 2);

        // row * 14 = row * (16 - 2)
        row_base = ({11'd0, r} << 4) - ({11'd0, r} << 1);

        temp_addr = ch_base + row_base + {11'd0, c};

        calc_addr = temp_addr[ADDR_WIDTH-1:0];
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state      <= S_IDLE;
        read_idx   <= 4'd0;

        mem_addr   <= {ADDR_WIDTH{1'b0}};
        mem_rd_en  <= 1'b0;

        valid_out  <= 1'b0;
        done       <= 1'b0;
        busy       <= 1'b0;

        out_row    <= 4'd0;
        out_col    <= 4'd0;
        in_ch      <= 6'd0;

        p0 <= {DATA_WIDTH{1'b0}};
        p1 <= {DATA_WIDTH{1'b0}};
        p2 <= {DATA_WIDTH{1'b0}};
        p3 <= {DATA_WIDTH{1'b0}};
        p4 <= {DATA_WIDTH{1'b0}};
        p5 <= {DATA_WIDTH{1'b0}};
        p6 <= {DATA_WIDTH{1'b0}};
        p7 <= {DATA_WIDTH{1'b0}};
        p8 <= {DATA_WIDTH{1'b0}};
    end
    else begin
        valid_out <= 1'b0;
        done      <= 1'b0;
        mem_rd_en <= 1'b0;

        case (state)

            S_IDLE: begin
                busy <= 1'b0;

                if (start) begin
                    busy     <= 1'b1;
                    out_row  <= req_row;
                    out_col  <= req_col;
                    in_ch    <= 6'd0;
                    read_idx <= 4'd0;
                    state    <= S_ADDR;
                end
            end

            S_ADDR: begin
                mem_rd_en <= 1'b1;

                case (read_idx)
                    4'd0: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd0, {1'b0, out_col} + 5'd0);
                    4'd1: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd0, {1'b0, out_col} + 5'd1);
                    4'd2: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd0, {1'b0, out_col} + 5'd2);

                    4'd3: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd1, {1'b0, out_col} + 5'd0);
                    4'd4: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd1, {1'b0, out_col} + 5'd1);
                    4'd5: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd1, {1'b0, out_col} + 5'd2);

                    4'd6: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd2, {1'b0, out_col} + 5'd0);
                    4'd7: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd2, {1'b0, out_col} + 5'd1);
                    default: mem_addr <= calc_addr(in_ch, {1'b0, out_row} + 5'd2, {1'b0, out_col} + 5'd2);
                endcase

                state <= S_WAIT;
            end

            S_WAIT: begin
                state <= S_CAP;
            end

            S_CAP: begin
                case (read_idx)
                    4'd0: p0 <= mem_dout;
                    4'd1: p1 <= mem_dout;
                    4'd2: p2 <= mem_dout;
                    4'd3: p3 <= mem_dout;
                    4'd4: p4 <= mem_dout;
                    4'd5: p5 <= mem_dout;
                    4'd6: p6 <= mem_dout;
                    4'd7: p7 <= mem_dout;
                    default: p8 <= mem_dout;
                endcase

                if (read_idx == 4'd8) begin
                    read_idx <= 4'd0;
                    state    <= S_OUT;
                end
                else begin
                    read_idx <= read_idx + 4'd1;
                    state    <= S_ADDR;
                end
            end

            S_OUT: begin
                valid_out <= 1'b1;
                state     <= S_NEXT;
            end

            S_NEXT: begin
                if (in_ch == 6'd63) begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end
                else begin
                    in_ch <= in_ch + 6'd1;
                    state <= S_ADDR;
                end
            end

            default: begin
                state <= S_IDLE;
            end

        endcase
    end
end

endmodule