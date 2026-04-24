`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Stores 4 previous rows and outputs a 5-row vertical window
//////////////////////////////////////////////////////////////////////////////////


module line_buffer_5 #(
    parameter DATA_W = 32,
    parameter IMG_W  = 128   // set this to your image width
)(
    input  wire clk,
    input  wire rst,
    input  wire valid_in,

    input  wire signed [DATA_W-1:0] din,

    output reg  valid_out,

    output reg signed [DATA_W-1:0] r0,
    output reg signed [DATA_W-1:0] r1,
    output reg signed [DATA_W-1:0] r2,
    output reg signed [DATA_W-1:0] r3,
    output reg signed [DATA_W-1:0] r4
);

/* line buffers (4 previous rows) */
reg signed [DATA_W-1:0] line0 [0:IMG_W-1];
reg signed [DATA_W-1:0] line1 [0:IMG_W-1];
reg signed [DATA_W-1:0] line2 [0:IMG_W-1];
reg signed [DATA_W-1:0] line3 [0:IMG_W-1];

reg [$clog2(IMG_W)-1:0] x;

/* pipeline registers */
integer i;

initial begin
    for (i = 0; i < IMG_W; i = i + 1) begin
        line0[i] = 0;
        line1[i] = 0;
        line2[i] = 0;
        line3[i] = 0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        x <= 0;
        valid_out <= 0;
        r0 <= 0; r1 <= 0; r2 <= 0; r3 <= 0; r4 <= 0;
    end
    else if (valid_in) begin
        /* output vertical window (old stored rows + current input) */
        r0 <= din;
        r1 <= line0[x];
        r2 <= line1[x];
        r3 <= line2[x];
        r4 <= line3[x];

        /* write into buffers (shift rows down at this column) */
        line0[x] <= din;
        line1[x] <= line0[x];
        line2[x] <= line1[x];
        line3[x] <= line2[x];

        /* update column index */
        if (x == IMG_W-1)
            x <= 0;
        else
            x <= x + 1;

        valid_out <= valid_in;
    end
    else begin
        valid_out <= 0;
    end
end

endmodule
