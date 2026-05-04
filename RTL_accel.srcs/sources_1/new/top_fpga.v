`timescale 1ns / 1ps

// Minimal Basys 3 demo wrapper for tensor_accel.
// Feeds constant gradients (ix=1, iy=2, it=-1) continuously and
// displays the lower 8 bits of sxx on LEDs, plus valid_out on LED[8].
//
// Expected steady-state: sxx = 25 (5x5 box filter of ix^2=1)
//   -> sxx[7:0] = 0x19 = 0b00011001
//   -> LED[8] (valid_out) stays ON once pipeline fills (~640 cycles at reset)

module top (
    input  wire        clk,   // W5  - 100 MHz oscillator
    input  wire        btnc,  // T17 - center button, active-high reset
    output wire [15:0] led    // LEDs LD0-LD15
);

// ── Power-on + button reset ───────────────────────────────────────────────────
// rst stays high for 16 clock cycles after power-up or button press.
reg [3:0] rst_ctr = 4'hF;
wire rst = (rst_ctr != 4'h0) | btnc;

always @(posedge clk) begin
    if (btnc)
        rst_ctr <= 4'hF;
    else if (rst_ctr != 4'h0)
        rst_ctr <= rst_ctr - 1;
end

// ── Constant synthetic gradient inputs ───────────────────────────────────────
localparam signed [15:0] IX =  16'sd1;
localparam signed [15:0] IY =  16'sd2;
localparam signed [15:0] IT = -16'sd1;

// ── tensor_accel instance ─────────────────────────────────────────────────────
wire        valid_out;
wire signed [31:0] sxx, sxy, syy, sxt, syt;

tensor_accel #(
    .DATA_W(16),
    .ACC_W (32),
    .IMG_W (128)
) u_accel (
    .clk      (clk),
    .rst      (rst),
    .valid_in (1'b1),   // drive valid every cycle after reset
    .ix       (IX),
    .iy       (IY),
    .it       (IT),
    .valid_out(valid_out),
    .sxx      (sxx),
    .sxy      (sxy),
    .syy      (syy),
    .sxt      (sxt),
    .syt      (syt)
);

// ── LED mapping ───────────────────────────────────────────────────────────────
// LED[7:0]  : sxx[7:0]  - expect 0x19 (= 25 decimal) once pipeline fills
// LED[8]    : valid_out  - goes and stays HIGH once pipeline is primed
// LED[15:9] : tied low
assign led[7:0]  = sxx[7:0];
assign led[8]    = valid_out;
assign led[15:9] = 7'b0;

endmodule
