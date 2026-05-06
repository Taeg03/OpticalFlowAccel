`timescale 1ns / 1ps

// Minimal Basys 3 demo wrapper for tensor_accel.
// Feeds constant gradients (ix=1, iy=2, it=-1) continuously and
// displays the lower 8 bits of sxx on LEDs, plus valid_out on LED[8].
//
// Expected steady-state: sxx = 25 (5x5 box filter of ix^2=1)
//   -> sxx[7:0] = 0x19 = 0b00011001
//   -> LED[8] (valid_out) stays ON once pipeline fills (~640 cycles at reset)

module top (
    input  wire        clk,      // W5  - 100 MHz oscillator
    input  wire        btnc,     // T17 - center button, active-high reset
    output wire [15:0] led,      // LEDs LD0-LD15
    output wire        uart_txd  // USB-UART TX (to PC terminal)
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

// ── Animated synthetic gradient inputs ───────────────────────────────────────
// Drive ix/iy from a slow counter so sxx changes over time.
reg [25:0] slow_ctr = 26'd0;

always @(posedge clk) begin
    if (rst)
        slow_ctr <= 26'd0;
    else
        slow_ctr <= slow_ctr + 1'b1;
end

reg signed [15:0] ix_dyn;
reg signed [15:0] iy_dyn;
localparam signed [15:0] IT = -16'sd1;

always @(*) begin
    case (slow_ctr[25:23])
        3'd0: begin ix_dyn = 16'sd1;  iy_dyn = 16'sd2;  end
        3'd1: begin ix_dyn = 16'sd2;  iy_dyn = 16'sd1;  end
        3'd2: begin ix_dyn = 16'sd3;  iy_dyn = -16'sd1; end
        3'd3: begin ix_dyn = 16'sd1;  iy_dyn = -16'sd3; end
        3'd4: begin ix_dyn = -16'sd1; iy_dyn = -16'sd2; end
        3'd5: begin ix_dyn = -16'sd2; iy_dyn = -16'sd1; end
        3'd6: begin ix_dyn = -16'sd3; iy_dyn = 16'sd1;  end
        default: begin ix_dyn = -16'sd1; iy_dyn = 16'sd3; end
    endcase
end

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
    .ix       (ix_dyn),
    .iy       (iy_dyn),
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

// ── UART readback (115200 8N1) ──────────────────────────────────────────────
// Periodically send the full 32-bit sxx value as 8 hex characters + CRLF.
wire uart_ready;
reg  uart_valid = 1'b0;
reg  [7:0] uart_data = 8'h00;

uart_tx #(
    .CLK_HZ(100_000_000),
    .BAUD  (115200)
) u_uart_tx (
    .clk   (clk),
    .rst   (rst),
    .valid (uart_valid),
    .data  (uart_data),
    .ready (uart_ready),
    .txd   (uart_txd)
);

function [7:0] hex_ascii;
    input [3:0] nib;
    begin
        if (nib < 4'd10)
            hex_ascii = 8'd48 + nib; // '0'
        else
            hex_ascii = 8'd55 + nib; // 'A' - 10
    end
endfunction

reg [3:0]  uart_idx = 4'd0;
reg [31:0] sxx_latched = 32'd0;
reg        send_active = 1'b0;
wire       send_pulse = (slow_ctr == 26'd0);

always @(posedge clk) begin
    if (rst) begin
        uart_valid   <= 1'b0;
        uart_data    <= 8'h00;
        uart_idx     <= 4'd0;
        sxx_latched  <= 32'd0;
        send_active  <= 1'b0;
    end else begin
        uart_valid <= 1'b0;

        if (send_pulse && valid_out && !send_active) begin
            sxx_latched <= sxx;
            uart_idx    <= 4'd0;
            send_active <= 1'b1;
        end

        if (send_active && uart_ready) begin
            case (uart_idx)
                4'd0: uart_data <= hex_ascii(sxx_latched[31:28]);
                4'd1: uart_data <= hex_ascii(sxx_latched[27:24]);
                4'd2: uart_data <= hex_ascii(sxx_latched[23:20]);
                4'd3: uart_data <= hex_ascii(sxx_latched[19:16]);
                4'd4: uart_data <= hex_ascii(sxx_latched[15:12]);
                4'd5: uart_data <= hex_ascii(sxx_latched[11:8]);
                4'd6: uart_data <= hex_ascii(sxx_latched[7:4]);
                4'd7: uart_data <= hex_ascii(sxx_latched[3:0]);
                4'd8: uart_data <= 8'h0D; // CR
                default: uart_data <= 8'h0A; // LF
            endcase

            uart_valid <= 1'b1;

            if (uart_idx == 4'd9)
                send_active <= 1'b0;
            else
                uart_idx <= uart_idx + 1'b1;
        end
    end
end

endmodule

// Simple 8N1 UART transmitter with valid/ready handshake.
module uart_tx #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD   = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       valid,
    input  wire [7:0] data,
    output wire       ready,
    output reg        txd
);
    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam integer CNT_W = (CLKS_PER_BIT <= 2) ? 1 : $clog2(CLKS_PER_BIT);

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA  = 2'd2;
    localparam [1:0] ST_STOP  = 2'd3;

    reg [1:0]  state = ST_IDLE;
    reg [CNT_W-1:0] clk_cnt = {CNT_W{1'b0}};
    reg [2:0] bit_idx = 3'd0;
    reg [7:0] shreg = 8'h00;

    assign ready = (state == ST_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state   <= ST_IDLE;
            clk_cnt <= {CNT_W{1'b0}};
            bit_idx <= 3'd0;
            shreg   <= 8'h00;
            txd     <= 1'b1;
        end else begin
            case (state)
                ST_IDLE: begin
                    txd <= 1'b1;
                    clk_cnt <= {CNT_W{1'b0}};
                    bit_idx <= 3'd0;
                    if (valid) begin
                        shreg <= data;
                        state <= ST_START;
                    end
                end

                ST_START: begin
                    txd <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
                        state <= ST_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                ST_DATA: begin
                    txd <= shreg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
                        if (bit_idx == 3'd7)
                            state <= ST_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                ST_STOP: begin
                    txd <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
                        state <= ST_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
