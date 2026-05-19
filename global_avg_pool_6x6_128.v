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

parameter S_IDLE  = 3'd0;
parameter S_CLEAR = 3'd1;
parameter S_ACCUM = 3'd2;
parameter S_OUT   = 3'd3;
parameter S_DONE  = 3'd4;

reg [2:0] state;

reg [7:0] clear_idx;
reg [7:0] out_idx;
reg [12:0] in_count;

reg signed [63:0] acc_mem [0:127];

wire signed [63:0] in_ext;
wire signed [63:0] avg_value;

assign in_ext = {{32{in_data[31]}}, in_data};
assign avg_value = acc_mem[out_idx[6:0]] / 64'sd36;

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
    end
    else begin
        valid_out <= 1'b0;

        case (state)

            S_IDLE: begin
                busy <= 1'b0;
                done <= 1'b0;

                if (start) begin
                    busy <= 1'b1;
                    clear_idx <= 8'd0;
                    state <= S_CLEAR;
                end
            end

            S_CLEAR: begin
                acc_mem[clear_idx[6:0]] <= 64'sd0;

                if (clear_idx == 8'd127) begin
                    in_count <= 13'd0;
                    state <= S_ACCUM;
                end
                else begin
                    clear_idx <= clear_idx + 8'd1;
                end
            end

            S_ACCUM: begin
                if (valid_in) begin
                    acc_mem[in_ch] <= acc_mem[in_ch] + in_ext;

                    if (in_count == 13'd4607) begin
                        out_idx <= 8'd0;
                        state <= S_OUT;
                    end
                    else begin
                        in_count <= in_count + 13'd1;
                    end
                end
            end

            S_OUT: begin
                valid_out <= 1'b1;
                out_ch <= out_idx[6:0];
                out_data <= avg_value;

                if (out_idx == 8'd127) begin
                    done <= 1'b1;
                    state <= S_DONE;
                end
                else begin
                    out_idx <= out_idx + 8'd1;
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