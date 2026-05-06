`timescale 1ns/1ps

module tb_tensor_active;

reg clk     = 0;
reg rst     = 1;
reg valid_in = 0;

reg signed [15:0] ix = 0;
reg signed [15:0] iy = 0;
reg signed [15:0] it = 0;

wire valid_out;
wire signed [31:0] sxx, sxy, syy, sxt, syt;

/* instance name matches implementation hierarchy so SAIF paths align */
tensor_accel u_accel (
    .clk      (clk),
    .rst      (rst),
    .valid_in (valid_in),
    .ix       (ix),
    .iy       (iy),
    .it       (it),
    .valid_out(valid_out),
    .sxx      (sxx),
    .sxy      (sxy),
    .syy      (syy),
    .sxt      (sxt),
    .syt      (syt)
);

/* 100 MHz clock */
always #5 clk = ~clk;

integer i;

initial begin
    #20;
    rst      = 0;
    valid_in = 1;

    for (i = 0; i < 10000; i = i + 1) begin
        @(posedge clk);
        ix <= $random;
        iy <= $random;
        it <= $random;
    end

    valid_in = 0;
    #100;
    $finish;
end

endmodule
