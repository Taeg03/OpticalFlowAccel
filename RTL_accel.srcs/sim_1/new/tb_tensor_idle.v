`timescale 1ns/1ps

module tb_tensor_idle;

reg clk  = 0;
reg btnc = 1;  /* hold reset asserted: clock tree runs, all registers frozen */

wire [15:0] led;
wire        uart_txd;

top dut (
    .clk     (clk),
    .btnc    (btnc),
    .led     (led),
    .uart_txd(uart_txd)
);

/* 100 MHz clock */
always #5 clk = ~clk;

initial begin
    #100000;
    $finish;
end

endmodule
