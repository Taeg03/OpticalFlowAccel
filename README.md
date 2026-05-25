# OpticalFlowAccel

A hardware-accelerated **optical flow structure tensor** computation engine implemented in Verilog, targeting the Xilinx Artix-7 XC7A35T FPGA on the Digilent Basys 3 board. The design achieves **one pixel per clock cycle** throughput after pipeline fill, yielding ~122 MP/s at 100 MHz.

---

## Table of Contents

- [Background](#background)
- [Architecture](#architecture)
- [Module Breakdown](#module-breakdown)
- [Resource Utilization](#resource-utilization)
- [Timing](#timing)
- [Power](#power)
- [Performance vs CPU](#performance-vs-cpu)
- [File Structure](#file-structure)
- [Simulation & Verification](#simulation--verification)
- [FPGA Demo](#fpga-demo)
- [Building in Vivado](#building-in-vivado)
- [Key Findings](#key-findings)

---

## Background

The **structure tensor** (also called the second-moment matrix) is a core primitive in many computer vision algorithms, including Lucas-Kanade optical flow, corner detection, and feature tracking. For a pixel with spatial gradients Ix, Iy and temporal gradient It, the five tensor products summed over a 5×5 neighborhood are:

| Component | Formula |
|-----------|---------|
| Sxx | Σ Ix² |
| Sxy | Σ Ix·Iy |
| Syy | Σ Iy² |
| Sxt | Σ Ix·It |
| Syt | Σ Iy·It |

Computing these in software is memory-bound and throughput-limited. This project implements the computation in a fully streaming RTL pipeline that produces one output tensor element per clock cycle at full image rate.

---

## Architecture

The accelerator is a **4-stage streaming pipeline**. Five identical sub-pipelines run in parallel, one for each tensor component.

```
  Ix, Iy, It (16-bit signed, 1 px/cycle)
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 1 — Multiply                                     │
│  Compute: ixix, ixiy, iyiy, ixit, iyit                  │
│  Latency: 1 cycle                                       │
└───────────────────────┬─────────────────────────────────┘
                        │ 5 × 32-bit products
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 2 — Horizontal 5-tap Box Filter (box_filter_h5)  │
│  Sliding window sum across each row: sum += new - old   │
│  Valid after 4-cycle window fill; resets per row        │
│  Latency: 4+ cycles                                     │
└───────────────────────┬─────────────────────────────────┘
                        │ 5 × 32-bit row-filtered sums
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 3 — Line Buffer (line_buffer_5)                  │
│  Stores 4 prior rows; presents 5-row window to Stage 4  │
│  Uses BRAM; column-major addressing per IMG_W           │
│  Latency: IMG_W × 4 cycles (vertical window fill)       │
└───────────────────────┬─────────────────────────────────┘
                        │ 5 rows × 5 components = 25 values
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 4 — Vertical 5-tap Accumulation (box_filter_v5)  │
│  Combinatorial sum of r0..r4 for each component         │
│  Latency: 1 cycle                                       │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
            Sxx, Sxy, Syy, Sxt, Syt (32-bit, valid_out)
```

After the pipeline fills, every clock cycle produces one fully accumulated structure tensor.

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_W`  | 16 | Bit-width of input gradient samples |
| `ACC_W`   | 32 | Bit-width of accumulation registers |
| `IMG_W`   | 128 | Image width in pixels |

---

## Module Breakdown

### `tensor_accel.v` — Top-Level Accelerator

Instantiates the four pipeline stages for all five tensor components. Exposes a simple streaming interface:

| Port | Direction | Description |
|------|-----------|-------------|
| `clk` | input | System clock |
| `rst` | input | Synchronous reset, active-high |
| `ix`, `iy`, `it` | input `[DATA_W-1:0]` | Signed gradient inputs |
| `valid_in` | input | Input data valid |
| `sxx`, `sxy`, `syy`, `sxt`, `syt` | output `[ACC_W-1:0]` | Structure tensor outputs |
| `valid_out` | output | Output data valid |

### `line_buffer_5.v` — Vertical Line Buffer

Maintains a circular buffer of the 4 most recent rows. On each clock, shifts the oldest row out and the newest row in. Outputs pixel values from the current position across all 5 rows simultaneously (r0 = current, r1–r4 = 4 prior rows). Uses block RAM for storage.

### `box_filter_h5.v` — Horizontal 5-tap Box Filter

Running-sum implementation of a causal 5-tap sliding window:

```
sum_new = sum_old + pixel_new - pixel_oldest
```

Resets internal state at the end of each row (`x == IMG_W-1`) so rows are processed independently. Output is valid after the first 4-cycle window fill per row.

### `box_filter_v5.v` — Vertical 5-tap Box Filter

Combinatorial direct sum of 5 row values from the line buffer:

```
sum = r0 + r1 + r2 + r3 + r4
```

One cycle of registered output latency. No state beyond the pipeline register.

### `top_fpga.v` — Basys 3 Demo Wrapper

Wraps `tensor_accel` with:
- A synthetic gradient generator that slowly cycles through 8 gradient patterns (increments every ~2^26 cycles so patterns are held long enough to observe on LEDs)
- A 16-cycle power-on reset counter
- LED output: `LED[7:0]` = lower 8 bits of Sxx; `LED[8]` = `valid_out`
- UART transmitter at 115200 baud 8N1 streaming Sxx values to a serial terminal

Expected Sxx readback for constant `Ix=1`: `0x19` (25 decimal = 5×5 filter of 1²).

---

## Resource Utilization

Synthesized and implemented in Vivado 2025.1, targeting **Xilinx XC7A35T (Artix-7)** on the Basys 3 board.

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUT | ~515 | 20,800 | **1.48%** |
| Flip-Flop | ~459 | 41,600 | **1.13%** |
| BRAM | 1 | 50 | **2%** |
| DSP48E1 | 1 | 90 | **1.1%** |
| SRL16E | 32 | — | 0.33% |
| CARRY4 | 47 | — | 0.58% |

The accelerator is extremely area-efficient, leaving the vast majority of device resources free for surrounding system logic.

### ASIC Gate Counts (Nangate45 reference library)

| Module | Gate Equivalent |
|--------|----------------|
| `box_filter_h5` | ~675 |
| `box_filter_v5` | ~722 |
| `line_buffer_5` | ~25,374 |
| `tensor_accel` (total) | ~142,841 |

The line buffer dominates area, confirming that **data movement — not arithmetic — is the primary cost** in streaming vision accelerators.

---

## Timing

| Metric | Value |
|--------|-------|
| Target clock period | 10 ns (100 MHz) |
| Worst Negative Slack (WNS) | +1.840 ns |
| Critical path delay | ~8.16 ns |
| Estimated Fmax | **~122 MHz** |

The design meets timing with comfortable margin at the 100 MHz target.

---

## Power

Measured via Vivado power analysis using Switching Activity Interchange Format (SAIF) files from dedicated simulation testbenches.

| Mode | Total | Dynamic | Static |
|------|-------|---------|--------|
| Idle (reset held, `tb_tensor_idle`) | **72 mW** | 3 mW | 68 mW |
| Active (streaming random gradients, `tb_tensor_active`) | **114 mW** | 42 mW | 72 mW |
| Active increase | +42 mW | +39 mW | — |

Dynamic power breakdown during active operation:
- I/O switching: ~24 mW (largest contributor)
- Line buffer BRAM/signal activity: ~9 mW
- Register/signal switching: ~7 mW

Static (leakage) power is dominated by the device itself (~68 mW), not the accelerator logic.

---

## Performance vs CPU

A behavioral reference was benchmarked using a Verilator-generated C++ model:

| Resolution | Software Runtime | Software Throughput |
|------------|-----------------|---------------------|
| 256×256 | 3.918 ms | 16.7 MP/s |
| 512×512 | 17.476 ms | 15.0 MP/s |
| 1024×1024 | 62.442 ms | 16.8 MP/s |

The FPGA accelerator at 122 MHz Fmax achieves **~122 MP/s** theoretical throughput — approximately **7.3× faster** than the CPU reference at 1024×1024 resolution, and up to **7.6×** at 512×512. Total system speedup (accounting for pipeline fill latency) is conservatively ~1.7× at small resolutions and approaches theoretical maximum for larger images where pipeline overhead amortizes.

---

## File Structure

```
OpticalFlowAccel/
├── RTL_accel.srcs/
│   ├── sources_1/new/
│   │   ├── tensor_accel.v       # Top-level accelerator
│   │   ├── top_fpga.v           # Basys 3 FPGA demo wrapper
│   │   ├── line_buffer_5.v      # 5-row vertical line buffer (BRAM)
│   │   ├── box_filter_h5.v      # Horizontal 5-tap sliding window filter
│   │   └── box_filter_v5.v      # Vertical 5-tap direct sum filter
│   ├── sim_1/new/
│   │   ├── accel_tb.v           # Comprehensive functional testbench
│   │   ├── tb_tensor_idle.v     # Power simulation — idle state
│   │   ├── tb_tensor_active.v   # Power simulation — active streaming
│   │   ├── tb_box_filter_h5.v   # Unit test: horizontal filter
│   │   ├── tb_box_filter_v5.v   # Unit test: vertical filter
│   │   └── tb_line_buffer_5.v   # Unit test: line buffer
│   ├── constrs_1/new/
│   │   ├── constraints.xdc      # Timing constraint: 10 ns clock
│   │   └── basys3_demo.xdc      # Basys 3 pin assignments
│   └── utils_1/
├── RTL_accel.runs/
│   ├── synth_1/                 # Synthesis outputs
│   └── impl_1/                  # Implementation outputs (routed)
├── RTL_accel.sim/               # Simulation artifacts (SAIF, waveforms)
├── RTL_accel.hw/                # Hardware definition files
├── Project Findings.txt         # Full synthesis, timing, power, area report
├── power_active.txt             # Vivado power report — active simulation
└── power_idle.txt               # Vivado power report — idle simulation
```

---

## Simulation & Verification

### Functional Testbench (`accel_tb.v`)

The main testbench drives `tensor_accel` through multiple phases:
- **Phase A–E**: Multi-width stimulus (IMG_W = 4, 8, ...) verifying horizontal and vertical filtering against precomputed golden values
- Tracks per-component peak and trough statistics
- Checks pipeline valid signal alignment

Run in Vivado:
1. Set `accel_tb` as the active simulation source
2. Run Behavioral Simulation (XSim)
3. Observe waveforms or console `$display` output

### Power Simulations

`tb_tensor_idle` and `tb_tensor_active` generate SAIF activity files for Vivado's power estimator:
- **Idle**: Holds `rst=1` for the entire simulation to isolate static power
- **Active**: Feeds random 16-bit gradients continuously with `valid_in=1`

After simulation, load the SAIF file in Vivado's Power Analysis tool for accurate switching-activity-based power estimation.

### Unit Tests

Individual testbenches (`tb_box_filter_h5.v`, `tb_box_filter_v5.v`, `tb_line_buffer_5.v`) verify each module in isolation before integration.

---

## FPGA Demo

### Hardware Required

- Digilent Basys 3 board (XC7A35T)
- USB-A to Micro-B cable
- (Optional) USB-Serial adapter or terminal to observe UART output at 115200 baud

### Pin Mapping

| Signal | Basys 3 Pin | Description |
|--------|-------------|-------------|
| `clk` | W5 | 100 MHz on-board oscillator |
| `rst` | T17 | Center pushbutton (active-high) |
| `LED[7:0]` | U16–V14 | Lower 8 bits of Sxx output |
| `LED[8]` | V13 | `valid_out` indicator |
| `uart_tx` | B18 | UART TX at 115200 baud 8N1 |

### Expected Behavior

On power-on, the design holds reset for 16 cycles, then begins cycling through gradient patterns. With a constant `Ix=1` pattern, `LED[7:0]` should display `0x19` (25 = 5×5 box sum of 1). The UART terminal will stream Sxx bytes continuously.

---

## Building in Vivado

1. Open Vivado 2025.1 (or compatible version)
2. **Open Project**: `File → Open Project → RTL_accel.xpr`
3. **Synthesis**: Click `Run Synthesis` in the Flow Navigator
4. **Implementation**: Click `Run Implementation`
5. **Generate Bitstream**: Click `Generate Bitstream`
6. **Program Device**: `Open Hardware Manager → Program Device` with Basys 3 connected

To change the target image width, modify the `IMG_W` parameter in `tensor_accel.v` and re-run synthesis.

---

## Key Findings

- **Throughput**: The streaming pipeline sustains 1 pixel/cycle after fill, achieving ~122 MP/s at the 122 MHz Fmax — up to **7.6× faster** than a CPU software reference.
- **Area efficiency**: The entire accelerator uses under 1.5% of available LUTs on the Artix-7, leaving the device almost entirely free for surrounding logic or larger designs.
- **Memory dominates**: The line buffer (BRAM-backed) accounts for ~18% of the total ASIC gate-equivalent area. In a real ASIC, optimizing the memory hierarchy (ping-pong SRAM, reduced buffering via algorithmic reformulation) would be the highest-leverage optimization.
- **Power**: The design draws 114 mW active / 72 mW idle at 100 MHz. I/O switching is the single largest dynamic power consumer (24 mW), suggesting that in a system context, reducing output bus width or gating outputs could yield meaningful savings.
- **Timing margin**: 1.84 ns positive WNS at 100 MHz leaves room to push the clock to ~122 MHz without design changes, or to insert additional pipeline stages for higher-frequency targets.
