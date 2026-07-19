# ==============================================================================
# Vivado Tcl: 导出 lut_dtc 后仿真所需文件 (综合后门级网表 + SDF)
#
# 器件: xcvu9p-flga2104-2L-e (UltraScale+)
#
# 用法:
#   cd C:\Users\Administrator\Desktop\GS\FPGA_PROJECT\FPGA_PROJECT\RTL\testbench\workbuddy
#   vivado -mode batch -source export_postsim.tcl
#
# 输出到 postsim/ 目录:
#   lut_dtc_synth.v     - 综合后门级网表
#   lut_dtc_synth.sdf   - 标准延迟文件 (含CARRY8真实延迟)
#   glbl.v              - 仿真全局模块
# ==============================================================================

set out_dir "C:/Users/Administrator/Desktop/GS/FPGA_PROJECT/FPGA_PROJECT/RTL/testbench/workbuddy/postsim"
file mkdir $out_dir

# ---- 单独综合 lut_dtc 模块 (网表小, SDF精准) ----
puts "=== Reading lut_dtc.v ==="
read_verilog "C:/Users/Administrator/Desktop/GS/FPGA_PROJECT/FPGA_PROJECT/RTL/all/workbuddy/lut_dtc.v"

# 设置目标器件 (从工程读取: xcvu9p-flga2104-2L-e)
set_part xcvu9p-flga2104-2L-e

puts "=== Synthesizing lut_dtc (funcsim mode) ==="
synth_design -top lut_dtc -mode funcsim

# 写门级网表 (funcsim = 功能仿真用, 含原语实例)
write_verilog -force -mode funcsim ${out_dir}/lut_dtc_synth.v

# 写 SDF 延迟文件 (这就是CARRY8真实延迟的来源)
write_sdf -force -mode funcsim ${out_dir}/lut_dtc_synth.sdf

# 写 glbl.v (Xilinx仿真必需的全局模块)
write_verilog -force -mode funcsim ${out_dir}/glbl.v

puts "=== Export complete ==="
puts "Files in ${out_dir}:"
foreach f [glob -nocomplain ${out_dir}/*] {
    puts "  [file tail $f] ([file size $f] bytes)"
}

close_project
