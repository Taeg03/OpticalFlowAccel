`timescale 1ns/1ps

module tb_box_filter_v5;

reg clk = 0;
reg rst = 1;
reg valid_in = 0;

reg signed [31:0] r0, r1, r2, r3, r4;

wire valid_out;
wire signed [31:0] sum_out;

box_filter_v5 dut (
    .clk(clk),
    .rst(rst),
    .valid_in(valid_in),
    .r0(r0),
    .r1(r1),
    .r2(r2),
    .r3(r3),
    .r4(r4),
    .valid_out(valid_out),
    .sum_out(sum_out)
);

/* clock */
always #5 clk = ~clk;

initial begin
    $display("Starting box_filter_v5 test");

    #10 rst = 0;

    @(posedge clk);
    valid_in = 1;

    /* simple test cases */
    r0 = 1; r1 = 2; r2 = 3; r3 = 4; r4 = 5; // sum = 15
    @(posedge clk);

    r0 = 10; r1 = 10; r2 = 10; r3 = 10; r4 = 10; // sum = 50
    @(posedge clk);

    r0 = 5; r1 = 4; r2 = 3; r3 = 2; r4 = 1; // sum = 15
    @(posedge clk);

    valid_in = 0;

    #50 $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        $display("t=%0t sum=%0d", $time, sum_out);
    end
end

endmodule