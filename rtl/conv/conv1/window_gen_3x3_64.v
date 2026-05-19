module window_gen_3x3_64 (
    input clk,
    input rst,
    input start,

    input [5:0] row,   // 0 ~ 61
    input [5:0] col,   // 0 ~ 61

    // image memory read interface
    output reg rd_en,
    output reg [11:0] rd_addr,

    input signed [15:0] rd_r,
    input signed [15:0] rd_g,
    input signed [15:0] rd_b,
    input rd_valid,

    // 3x3 RGB window output
    output reg signed [15:0] r00, r01, r02,
    output reg signed [15:0] r10, r11, r12,
    output reg signed [15:0] r20, r21, r22,

    output reg signed [15:0] g00, g01, g02,
    output reg signed [15:0] g10, g11, g12,
    output reg signed [15:0] g20, g21, g22,

    output reg signed [15:0] b00, b01, b02,
    output reg signed [15:0] b10, b11, b12,
    output reg signed [15:0] b20, b21, b22,

    output reg valid_out,
    output reg done,
    output reg busy
);

parameter IDLE = 2'd0;
parameter READ = 2'd1;
parameter DONE = 2'd2;

reg [1:0] state;

reg [11:0] base_addr;
reg [3:0] issue_idx;
reg [3:0] cap_idx;

wire [11:0] start_base_addr;

assign start_base_addr = {row, 6'b000000} + {6'b000000, col};

/* =========================
   offset generator
   ========================= */
function [11:0] offset_3x3;
    input [3:0] idx;
    begin
        case (idx)
            4'd0: offset_3x3 = 12'd0;
            4'd1: offset_3x3 = 12'd1;
            4'd2: offset_3x3 = 12'd2;

            4'd3: offset_3x3 = 12'd64;
            4'd4: offset_3x3 = 12'd65;
            4'd5: offset_3x3 = 12'd66;

            4'd6: offset_3x3 = 12'd128;
            4'd7: offset_3x3 = 12'd129;
            4'd8: offset_3x3 = 12'd130;

            default: offset_3x3 = 12'd0;
        endcase
    end
endfunction

/* =========================
   capture read data
   ========================= */
always @(posedge clk or posedge rst) begin
    if (rst) begin
        r00 <= 16'sd0; r01 <= 16'sd0; r02 <= 16'sd0;
        r10 <= 16'sd0; r11 <= 16'sd0; r12 <= 16'sd0;
        r20 <= 16'sd0; r21 <= 16'sd0; r22 <= 16'sd0;

        g00 <= 16'sd0; g01 <= 16'sd0; g02 <= 16'sd0;
        g10 <= 16'sd0; g11 <= 16'sd0; g12 <= 16'sd0;
        g20 <= 16'sd0; g21 <= 16'sd0; g22 <= 16'sd0;

        b00 <= 16'sd0; b01 <= 16'sd0; b02 <= 16'sd0;
        b10 <= 16'sd0; b11 <= 16'sd0; b12 <= 16'sd0;
        b20 <= 16'sd0; b21 <= 16'sd0; b22 <= 16'sd0;
    end else begin
        if (rd_valid) begin
            case (cap_idx)
                4'd0: begin r00 <= rd_r; g00 <= rd_g; b00 <= rd_b; end
                4'd1: begin r01 <= rd_r; g01 <= rd_g; b01 <= rd_b; end
                4'd2: begin r02 <= rd_r; g02 <= rd_g; b02 <= rd_b; end

                4'd3: begin r10 <= rd_r; g10 <= rd_g; b10 <= rd_b; end
                4'd4: begin r11 <= rd_r; g11 <= rd_g; b11 <= rd_b; end
                4'd5: begin r12 <= rd_r; g12 <= rd_g; b12 <= rd_b; end

                4'd6: begin r20 <= rd_r; g20 <= rd_g; b20 <= rd_b; end
                4'd7: begin r21 <= rd_r; g21 <= rd_g; b21 <= rd_b; end
                4'd8: begin r22 <= rd_r; g22 <= rd_g; b22 <= rd_b; end

                default: begin
                end
            endcase
        end
    end
end

/* =========================
   FSM
   ========================= */
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;

        rd_en <= 1'b0;
        rd_addr <= 12'd0;

        base_addr <= 12'd0;
        issue_idx <= 4'd0;
        cap_idx <= 4'd0;

        valid_out <= 1'b0;
        done <= 1'b0;
        busy <= 1'b0;
    end else begin
        rd_en <= 1'b0;
        valid_out <= 1'b0;
        done <= 1'b0;

        case (state)
            IDLE: begin
                busy <= 1'b0;
                issue_idx <= 4'd0;
                cap_idx <= 4'd0;

                if (start) begin
                    busy <= 1'b1;
                    base_addr <= start_base_addr;

                    rd_en <= 1'b1;
                    rd_addr <= start_base_addr + offset_3x3(4'd0);

                    issue_idx <= 4'd1;
                    cap_idx <= 4'd0;

                    state <= READ;
                end
            end

            READ: begin
                busy <= 1'b1;

                if (rd_valid) begin
                    if (cap_idx == 4'd8) begin
                        cap_idx <= 4'd0;
                        state <= DONE;
                    end else begin
                        cap_idx <= cap_idx + 4'd1;
                    end
                end

                if (issue_idx < 4'd9) begin
                    rd_en <= 1'b1;
                    rd_addr <= base_addr + offset_3x3(issue_idx);
                    issue_idx <= issue_idx + 4'd1;
                end
            end

            DONE: begin
                busy <= 1'b0;
                valid_out <= 1'b1;
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