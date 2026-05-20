`timescale 1ns/1ps

module cnn_led_status (
    clk,
    rst,
    final_valid,
    final_done,
    final_pred,
    tail_busy,
    led_pred,
    led_done,
    led_busy
);

input clk;
input rst;
input final_valid;
input final_done;
input final_pred;
input tail_busy;

output reg led_pred;
output reg led_done;
output led_busy;

assign led_busy = tail_busy;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        led_pred <= 1'b0;
        led_done <= 1'b0;
    end
    else begin
        if (final_done || final_valid) begin
            led_pred <= final_pred;
            led_done <= 1'b1;
        end
    end
end

endmodule