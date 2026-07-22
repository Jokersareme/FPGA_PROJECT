# FPGA DTC PLL Simulation - Summary

## What Works
- **Zero-delay simulation**: 200μs in ~0.8s (no CARRY8 # delays)
- **Analytical DTC compensation**: Computes compensated jitter from dtc_code variation
- **MASH 3rd order dithering**: dtc_code varies between edges (dcd up to ±11 with gain=8)
- **PLL lock**: locked_pll=1 at 200μs

## Jitter Analysis (200μs, 100 periods sampled)
| Metric | Reference | DTC @1ps/tap | DTC @0.1ps/tap |
|--------|-----------|--------------|-----------------|
| Avg Period | 114ps | 114ps | 114ps |
| Jitter | ±1.5ps (2%) | ±13ps (22%) | ±2.5ps (4%) |

- DTC IS affecting timing (code varies, changes with MASH output)
- Open-loop: compensation cannot converge due to MASH high-frequency noise
- Pipeline delay: code samples lag by ~1 period (114ns)
- Actual closed-loop operation would have PLL loop filter shaping noise

## Critical Bug Fixes Applied (source copies only)
1. **dff reg init**: `output reg Q = 0` — prevents X in ripple counters
2. **dtc_code_d1 init**: `reg [8:0] dtc_code_d1 = 0` — chicken-and-egg X propagation
3. **hk_efm sum_r init**: prevents MASH X propagation
4. **mash111 reg init**: all internal regs = 0
5. **Calibrator wait_cnt bug**: `wait_cnt <= 0` → `wait_cnt <= wait_cnt + 1` (source)
6. **CARRY8 model**: `initial CO = 0` for zero-delay simulation

## Why Calibration Fails
- calibrator needs `ce_rise` on `cal_mode_ext` (cal_start)
- VIO probe_out3 had `cal_start=1` constantly (no 0→1 edge)
- Fixed in xilinx_sim.v with vio_start pulse, but still not completing at 500μs

## iverilog v12 Limitations
- `assign #` delayed assignments: >64 events/edge causes SIGKILL
- `always @(*) with #0.010`: 256 CARRY8s × always blocks × events kills sim
- 512-tap delay line (behavior_dtc) can't simulate with delays
- Solution: zero-delay CARRY8 + analytical post-processing

## Files Created/Modified (in RTL/testbench/openclaw/)
- `models/carry8_model.v` — Zero-delay with init=0
- `models/behavior_dtc.v` — Behavioral DTC delay (64-tap, not used)
- `tb_top.v` — Full jitter analysis testbench
- `src/dtc/lut_dtc.v` — Simplified behavioral pass-through (no CARRY8)
- `src/fpga_ssc_pll_top.v` — Added dtc_code_d1/dtC_code_pipe init
- `xilinx_sim.v` — VIO model with cal_start pulse
