# 后仿真 (Post-Synthesis Simulation) 完整指南

## 概述

后仿真能看到 CARRY8 的真实延迟（15ps/tap），验证 code→delay 是否近似线性。
RTL 仿真是零延迟的，**只有后仿真才能确认延迟修复是否有效**。

---

## 步骤 1: 导出综合后网表 + SDF

### 方法 A: 在 Vivado GUI 里用 Tcl Console（推荐）

1. 打开 Vivado，打开你的 FPGA_SSC_PLL 工程
2. 底部找到 **Tcl Console** 面板
3. 逐行粘贴执行以下命令：

```tcl
# 设置路径
set out_dir "C:/Users/Administrator/Desktop/GS/FPGA_PROJECT/FPGA_PROJECT/RTL/testbench/workbuddy/postsim"
file mkdir $out_dir

# 读入 lut_dtc 源码
read_verilog "C:/Users/Administrator/Desktop/GS/FPGA_PROJECT/FPGA_PROJECT/RTL/all/workbuddy/lut_dtc.v"

# 设置目标器件 (你的工程用 xcvu9p-flga2104-2L-e)
set_part xcvu9p-flga2104-2L-e

# 综合 (funcsim 模式, 生成功能仿真网表)
synth_design -top lut_dtc -mode funcsim

# 写门级网表
write_verilog -force -mode funcsim ${out_dir}/lut_dtc_synth.v

# 写 SDF 延迟文件 ← 这个文件包含 CARRY8 真实延迟!
write_sdf -force -mode funcsim ${out_dir}/lut_dtc_synth.sdf

# 写 glbl.v (Xilinx 仿真必需)
write_verilog -force -mode funcsim ${out_dir}/glbl.v

# 完成
puts "Export done! Check $out_dir"
```

4. 执行完后，`postsim/` 目录下会有 3 个文件：
   - `lut_dtc_synth.v` — 门级网表
   - `lut_dtc_synth.sdf` — 延迟文件（关键！）
   - `glbl.v` — 全局模块

### 方法 B: 用批处理脚本

双击运行 `run_export.bat`（在 `RTL/testbench/workbuddy/` 目录下）。
它会调用 Vivado batch 模式执行同样的 Tcl 命令。

---

## 步骤 2: 运行后仿真

### 方法 A: 用 Vivado XSim（推荐，兼容性最好）

1. 在 Vivado Tcl Console 里执行：

```tcl
set sim_dir "C:/Users/Administrator/Desktop/GS/FPGA_PROJECT/FPGA_PROJECT/RTL/testbench/workbuddy"
cd $sim_dir

# 编译
xvlog -prj postsim_xsim.prj

# 精化 (elaborate)
xelab -L unisims_ver -L unimacro_ver -L xpm work.tb_lut_dtc_postsim glbl -s sim_postsim

# 运行
xsim sim_postsim -tclbatch xsim_run.tcl
```

2. 或者直接在 Vivado GUI 里：
   - Settings → Simulation → 设 top module 为 `tb_lut_dtc_postsim`
   - Simulation → Run Simulation → **Run Post-Synthesis Functional Simulation**
   - Vivado 会自动综合 + 生成网表 + 运行仿真

### 方法 B: 用 iverilog（如果支持 Xilinx 原语）

```bash
cd RTL/testbench/workbuddy
iverilog -o postsim.vvp -g2012 \
    -s tb_lut_dtc_postsim \
    tb_lut_dtc_postsim.v \
    postsim/lut_dtc_synth.v \
    postsim/glbl.v \
    -D XILINX_SIMULATION
vvp postsim.vvp
```

**注意**: iverilog 可能不认识网表里的某些 Xilinx 原语，推荐用 Vivado XSim。

---

## 步骤 3: 看结果

后仿真 testbench (`tb_lut_dtc_postsim.v`) 会输出：

```
========================================
  POST-SIM: Path A (dtc_sel=0) delay scan
========================================
  code   |  delay(ps)  |  dout
  -------+-------------+------
     0   |      45.2   |  1
    32   |     525.3   |  1
    64   |    1003.1   |  1
    96   |    1480.7   |  1
   128   |    1958.4   |  1
   ...
   480   |    7250.6   |  1
```

**关键验证点**：
1. delay 随 code 递增 → 延迟修复有效
2. delay/code ≈ 15ps → CARRY8 延迟透出来了
3. 段边界（code=64,128,...）处 delay 是否有台阶
4. Path A vs Path B 哪个线性度更好

---

## 文件清单

| 文件 | 说明 |
|------|------|
| `export_postsim.tcl` | Vivado Tcl 脚本，导出网表+SDF |
| `run_export.bat` | Windows 批处理，调用 Vivado batch |
| `tb_lut_dtc_postsim.v` | 后仿真 testbench（含 SDF 标注 + 延迟测量） |
| `postsim_xsim.prj` | XSim 工程文件（步骤2用） |
| `xsim_run.tcl` | XSim 运行脚本（步骤2用） |

---

## 常见问题

**Q: SDF 标注失败怎么办？**
A: 确认 SDF 文件路径正确。testbench 里 `$sdf_annotate("lut_dtc_synth.sdf", DUT)` 是相对路径，运行仿真时要在 `postsim/` 目录或调整路径。

**Q: 网表里有不认识的原语？**
A: 用 Vivado XSim，它自带所有 Xilinx 原语库。iverilog 需要 `carry8_model.v` 但后仿真网表用的原语名可能和行为模型不一致。

**Q: 延迟值和预期差很多？**
A: 后仿真延迟是综合+布局后的估计值，实际硅片延迟可能不同。但 code→delay 的**趋势和线性度**是可靠的。
