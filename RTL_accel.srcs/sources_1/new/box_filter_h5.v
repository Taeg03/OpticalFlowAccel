// horizontal sliding window

`timescale 1ns / 1ps

module box_filter_h5 #(
    parameter DATA_W = 32,
    parameter IMG_W  = 128
)(
    input  wire clk,
    input  wire rst,
    input  wire valid_in,

    input  wire signed [DATA_W-1:0] pixel_in,

    output reg  valid_out,
    output reg signed [DATA_W-1:0] sum_out
);

reg signed [DATA_W-1:0] w0, w1, w2, w3, w4;
reg signed [DATA_W-1:0] running_sum;
reg [31:0] x;
wire signed [DATA_W-1:0] next_sum;

assign next_sum = running_sum + pixel_in - w4;

always @(posedge clk) begin
    if (rst) begin
        w0 <= 0;
        w1 <= 0;
        w2 <= 0;
        w3 <= 0;
        w4 <= 0;
        running_sum <= 0;
        sum_out <= 0;
        valid_out <= 0;
        x <= 0;
    end
    else if (valid_in) begin

        /* compute next running sum */
        sum_out <= next_sum;
        valid_out <= 1;

        if (x == IMG_W-1) begin
            /* end-of-row: emit this pixel then clear state for next row */
            x <= 0;
            w0 <= 0;
            w1 <= 0;
            w2 <= 0;
            w3 <= 0;
            w4 <= 0;
            running_sum <= 0;
        end
        else begin
            x <= x + 1;

            /* shift window */
            w4 <= w3;
            w3 <= w2;
            w2 <= w1;
            w1 <= w0;
            w0 <= pixel_in;

            /* update state */
            running_sum <= next_sum;
        end
    end
    else begin
        valid_out <= 0;
    end
end

endmodule
