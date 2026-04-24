`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Direct sum
//////////////////////////////////////////////////////////////////////////////////

module box_filter_v5 #(
    parameter DATA_W = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire valid_in,

    input  wire signed [DATA_W-1:0] r0,
    input  wire signed [DATA_W-1:0] r1,
    input  wire signed [DATA_W-1:0] r2,
    input  wire signed [DATA_W-1:0] r3,
    input  wire signed [DATA_W-1:0] r4,

    output reg  valid_out,
    output reg signed [DATA_W-1:0] sum_out
);

always @(posedge clk) begin
    if (rst) begin
        sum_out <= 0;
        valid_out <= 0;
    end
    else if (valid_in) begin
        /* full 5x5 accumulation (vertical stage) */
        sum_out <= r0 + r1 + r2 + r3 + r4;
        valid_out <= 1;
    end
    else begin
        valid_out <= 0;
    end
end

endmodule