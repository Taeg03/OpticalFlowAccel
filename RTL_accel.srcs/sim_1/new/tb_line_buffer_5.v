`timescale 1ns/1ps

module tb_line_buffer_5;

parameter IMG_W = 4;

reg clk = 0;
reg rst = 1;
reg valid_in = 0;

reg signed [31:0] din;

wire valid_out;
wire signed [31:0] r0, r1, r2, r3, r4;

line_buffer_5 #(
    .DATA_W(32),
    .IMG_W(IMG_W)
) dut (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .din(din),
    .valid_out(valid_out),
    .r0(r0),
    .r1(r1),
    .r2(r2),
    .r3(r3),
    .r4(r4)
);

/* clock */
always #5 clk = ~clk;

integer i;

initial begin
    $display("Starting line_buffer_5 test");

    #10 rst = 0;

    @(posedge clk);
    valid_in = 1;

    /*
    Feed a 4x5 "image":

    Row 0:  1  2  3  4
    Row 1:  5  6  7  8
    Row 2:  9 10 11 12
    Row 3: 13 14 15 16
    Row 4: 17 18 19 20
    */

    for (i = 1; i <= 20; i = i + 1) begin
        @(posedge clk);
        din = i;
    end

    valid_in = 0;

    #100 $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        $display("x=%0d | r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d",
            dut.x, r0, r1, r2, r3, r4);
    end
end

endmodule