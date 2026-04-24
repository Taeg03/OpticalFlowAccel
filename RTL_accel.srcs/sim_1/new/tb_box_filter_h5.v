`timescale 1ns/1ps

module tb_box_filter_h5;

reg clk = 0;
reg rst = 1;
reg valid_in = 0;

reg signed [31:0] pixel_in = 0;

wire valid_out;
wire signed [31:0] sum_out;

box_filter_h5 dut (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .pixel_in(pixel_in),
    .valid_out(valid_out),
    .sum_out(sum_out)
);

/* clock */
always #5 clk = ~clk;

/* stimulus */
integer i;

initial begin
    $display("Starting box_filter_h5 test");

    /* release reset */
    #10 rst = 0;

    @(posedge clk);

    /* feed sequence 1..10 */
    for (i = 1; i <= 10; i = i + 1) begin
        @(posedge clk);
        valid_in = 1;
        pixel_in = i;
    end

    /* stop feeding pixels */
    @(posedge clk);
    valid_in = 0;

    #50 $finish;
end

/* monitor */
always @(posedge clk) begin
    if (valid_out) begin
        $display("t=%0t  in=%0d  sum=%0d", $time, pixel_in, sum_out);
    end
end

endmodule