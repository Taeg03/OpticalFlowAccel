## Basys 3 minimal constraints for tensor_accel streaming demo
## Only pins actually used by top.v are uncommented.

## ── Clock ────────────────────────────────────────────────────────────────────
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD  LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

## ── Reset (center button, active-high) ───────────────────────────────────────
set_property PACKAGE_PIN T17 [get_ports btnc]
set_property IOSTANDARD  LVCMOS33 [get_ports btnc]

## ── LEDs ─────────────────────────────────────────────────────────────────────
## LED[7:0] = sxx[7:0]   (expect 0x19 = LEDs 0,3,4 ON when pipeline settles)
## LED[8]   = valid_out  (turns ON and stays ON after ~640 cycles)

set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[1]}]

set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[2]}]

set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[3]}]

set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[4]}]

set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[5]}]

set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[6]}]

set_property PACKAGE_PIN V14 [get_ports {led[7]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[7]}]

set_property PACKAGE_PIN V13 [get_ports {led[8]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[8]}]

## LED[15:9] are driven to 0 in RTL; still need IOSTANDARDs for synthesis.
set_property PACKAGE_PIN V3  [get_ports {led[9]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[9]}]

set_property PACKAGE_PIN W3  [get_ports {led[10]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[10]}]

set_property PACKAGE_PIN U3  [get_ports {led[11]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[11]}]

set_property PACKAGE_PIN P3  [get_ports {led[12]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[12]}]

set_property PACKAGE_PIN N3  [get_ports {led[13]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[13]}]

set_property PACKAGE_PIN P1  [get_ports {led[14]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[14]}]

set_property PACKAGE_PIN L1  [get_ports {led[15]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[15]}]

## ── USB-UART TX (FPGA -> PC) ────────────────────────────────────────────────
set_property PACKAGE_PIN B18 [get_ports uart_txd]
set_property IOSTANDARD  LVCMOS33 [get_ports uart_txd]
