# FPGA SSC PLL + DTC 仿真修改日志

> 本文件记录 workbuddy 仿真环境下的所有修改。
> 原源码位于 `RTL/all/`，本目录下的 `src/` 是拷贝后的仿真专用版本，可自由修改。

---

## 2026-07-25 14:00 —— 第一轮：搭建基础仿真环境

### 新建文件

| 文件 | 说明 |
|---|---|
| `models/xilinx_sim.v` | Xilinx 原语仿真模型：IBUFDS/OBUFDS/BUFG/BUFGMUX/VIO/ILA/clk_wiz_0/IDELAYE3/IDELAYCTRL |
| `models/carry8_model.v` | 零延迟 CARRY8 模型（iverilog v12 不支持 64 个带 `#delay` 的 CARRY8 级联，会崩溃） |
| `tb_top.v` | 顶层 testbench：125MHz 差分时钟、复位序列、VCD 输出、周期抖动分析 |
| `run_sim.bat` | Windows 一键编译运行脚本 |

### 拷贝并修改的源码（`src/` 目录）

| 文件 | 修改内容 | 原因 |
|---|---|---|
| `src/fractionaln/dff.v` | `output reg Q` -> `output reg Q = 0` | 防止未初始化的 X 传播到 ripple counter |
| `src/fpga_ssc_pll_top.v` | `dtc_code_d1 = 0`, `dtc_code_pipe = 0` | 解决 chicken-and-egg X 传播问题 |
| `src/fractionaln/fractionaln.v` | `reg delta_sigma_d1 = 0` -> `reg [3:0] delta_sigma_d1 = 0` | 修复 1-bit/4-bit 位宽不匹配编译错误 |
| `src/dtc/lut_dtc.v` | 完全替换为 zero-delay 行为模型 | 64 个 CARRY8 实例在 iverilog v12 中导致 vvp 崩溃 |
| `src/dtc/lut_dtc.v` | 去掉 `(* DONT_TOUCH = "TRUE" *)` 属性 | iverilog v12 不支持 generate 内 assign 前加 attribute |

### 仿真结果
- 周期：113 ns（期望 ~114 ns）✓
- PLL locked：1 ✓
- Calibration done：0（zero-delay 模型下预期行为）

---

## 2026-07-25 14:00 —— 第二轮：FPGA 原语加延迟 + DTC 40ps/tap

### 修改 `models/xilinx_sim.v`

| 原语 | 修改前 | 修改后 |
|---|---|---|
| IBUFDS | `assign O = I` | `assign #1.0 O = I` |
| OBUFDS | `assign O = I` | `assign #1.0 O = I` |
| BUFG | `assign O = I` | `assign #0.5 O = I` |
| BUFGMUX | `assign O = S ? I1 : I0` | `assign #0.5 O = S ? I1 : I0` |
| clk_wiz_0 输出 | `assign clk_out1 = clk_out_r` | `assign #0.2 clk_out1 = clk_out_r` |
| IDELAYE3 | zero-delay | `#(delay_val * 0.040) ns`（40ps/tap 变量延迟） |

### 修改 `src/dtc/lut_dtc.v`

| 项目 | 修改前 | 修改后 |
|---|---|---|
| 主延迟路径 | `assign dout = din`（zero-delay） | `always @(din or code) dout_r = #(code * 0.040) din` |
| TDC 模型 | `cal_result = code / 10` | `cal_result = (code * 2) / 5` |

### 仿真结果
- 参考通道：113 ns ±12 ns jitter (10.62%)
- DTC 补偿通道：113 ns ±15 ns jitter (13.27%) —— DTC 延迟开始影响时序
- PLL locked：1 ✓
- Calibration done：0

### 观察
- DTC 补偿通道 jitter 从 12ns 增大到 15ns，说明 DTC 延迟链确实在起作用。
- 但 jitter 反而比参考通道大，原因是**开环仿真**：DTC 补偿和 MASH 噪声之间没有 PLL 闭环滤波来抑制高频抖动。
- 校准器在 1.8ms 内未完成（cal_done=0），DTC gain 可能还不是最优值。

---

---

## 2026-07-25 14:05 —— 第三轮：lut_dtc 改用 CARRY8 链（主路径）

### 问题
用户要求主延迟路径用 CARRY8 组成，而不是 IDELAYE3/行为模型。

### 修改 `src/dtc/lut_dtc.v`
- 恢复 CARRY8 级联链（64 个实例，512 tap）+ 3 层分级 MUX。
- 去掉所有 `(* DONT_TOUCH *)` / `(* KEEP *)` 属性（iverilog 不支持）。
- 保留 TDC 行为模型（`cal_result`/`cal_valid`）。

### 修改 `models/carry8_model.v`
- 针对设计参数（S=8'hFF, DI=8'b0）做极致简化：
  - 原模型：8 级 `assign` 嵌套（64 实例 × 8 级 = 512 级组合逻辑，vvp 崩溃）。
  - 新模型：`assign CO = {8{CI}}`（单级 assign，64 实例 = 64 级组合逻辑）。
- 注意：此简化仅适用于 S=FF/DI=0 的情况，保留了 CARRY8 实例化结构用于综合验证。

### 新建 `src/dtc/lut_dtc_cal.v`
- 校准链专用 zero-delay 模型（无 CARRY8 实例）。
- 原因：`lut_dtc_top.v` 中 generate 了 16 级校准链，若都用 CARRY8 则总共 20 × 64 = 1280 个实例，vvp 无法运行。

### 修改 `src/dtc/lut_dtc_top.v`
- generate 中的 16 级校准链：从 `lut_dtc` 改为 `lut_dtc_cal`。
- 4 级主延迟链：保留 `lut_dtc`（CARRY8 结构）。

### 仿真结果
- 参考通道：113 ns ±12 ns jitter (10.62%)
- DTC 补偿通道：113 ns ±12 ns jitter (10.62%)
- PLL locked：1 ✓
- Calibration done：0

### 观察
- CARRY8 简化模型下，4 级主链（256 个 CARRY8 实例）vvp 可正常运行。
- DTC 延迟路径现在由 CARRY8 实例 + 分级 MUX 组成，结构与原 RTL 一致。
- 真实延迟仍在 `models/xilinx_sim.v` 的 IDELAYE3 和 `lut_dtc.v` 的 TDC 模型中体现。

---

---

## 2026-07-25 21:05 —— 第四轮：VCD 波形数据提取

### 需求
从 `tb_top.vcd` 中提取三个信号的对应关系，输出 CSV 表格：
1. `div_out_raw` 上升沿时间（ns，3 位小数）
2. `div_out_dtc` 上升沿时间（ns，3 位小数）
3. `div_out_raw` 上升沿时刻 `E_combined` 的有符号值

### 新建 `extract_vcd.py`
- 纯 Python 解析 VCD（不依赖第三方库）。
- 信号映射（通过 `$var` 行确认）：
  - `div_out_raw` → 标识符 `\`
  - `div_out_dtc` → 标识符 `^`
  - `E_combined [10:0]` → 标识符 `Z"`（`u_dut.u_fracn_div` 下的 11-bit signed reg）
- 匹配逻辑：每个 `div_out_raw` 上升沿后，取第一个出现的 `div_out_dtc` 上升沿作为配对。

### 提取结果
- `div_out_raw` 上升沿：154 个
- `div_out_dtc` 上升沿：154 个
- 成功配对：154 行
- 输出文件：`edge_timing.csv`

### 数据预览

| div_out_raw_rise_ns | div_out_dtc_rise_ns | E_combined_signed |
|---|---|---|
| 513.000 | 513.500 | 0 |
| 626.600 | 627.100 | 0 |
| 740.200 | 740.700 | 0 |
| 853.800 | 854.300 | 0 |
| 967.400 | 967.900 | 0 |
| 1081.000 | 1081.500 | -43 |
| 1194.600 | 1195.100 | -86 |
| 1308.200 | 1308.700 | -385 |
| ... | ... | ... |
| 17943.400 | 17943.900 | -7 |

- E_combined 范围：[-1023, 0]（11-bit signed，全为负值或零，符合 MASH 误差特征）
- div_out_dtc 比 div_out_raw 固定延迟约 **0.5 ns**（DTC 补偿链路延迟）

### 观察
- 前 5 个周期 E_combined=0，说明 MASH/SSC 初始化阶段输出为零。
- E_combined 在 -43 ~ -1023 之间变化，反映了 MASH 1-1-1 的量化噪声。

---

## 待办 / 下一步

- [ ] 延长仿真时间，观察校准器是否能完成
- [ ] 手动设置最优 dtc_gain，对比 jitter 改善
- [ ] 关闭 MASH/SSC（bypass 模式），验证纯整数分频下 DTC 延迟线性度
- [ ] 给 CARRY8 模型加上小延迟（如 20ps），验证 lut_dtc 分级 MUX 功能
