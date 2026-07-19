# ==============================================================================
# Vivado Tcl: 一键导出后仿真文件 + 运行 XSim 后仿真
#
# 用法: 在 Vivado Tcl Console 里 source 此文件
#   source C:/Users/Administrator/Desktop/GS/FPGA_PROJECT/FPGA_PROJECT/RTL/testbench/workbuddy/run_postsim_all.tcl
#
# 或者命令行:
#   vivado -mode batch -source run_postsim_all.tcl
# ==============================================================================

set work_dir "C:/Users/Administrator/Desktop/GS/FPGA_PROJECT/FPGA_PROJECT/RTL/testbench/workbuddy"
set out_dir  "${work_dir}/postsim"
set src_dir  "C:/Users/Administrator/Desktop/GS/FPGA_PROJECT/FPGA_PROJECT/RTL/all/workbuddy"

file mkdir $out_dir
cd $work_dir

# ==============================================================================
# Step 1: 综合 lut_dtc, 导出门级网表 + SDF
# ==============================================================================
puts "========================================"
puts "  Step 1: Synthesize lut_dtc"
puts "========================================"

read_verilog "${src_dir}/lut_dtc.v"
set_part xcvu9p-flga2104-2L-e
synth_design -top lut_dtc -mode funcsim

write_verilog -force -mode funcsim ${out_dir}/lut_dtc_synth.v
write_sdf     -force -mode funcsim ${out_dir}/lut_dtc_synth.sdf
write_verilog -force -mode funcsim ${out_dir}/glbl.v

puts "  Netlist: ${out_dir}/lut_dtc_synth.v"
puts "  SDF:     ${out_dir}/lut_dtc_synth.sdf"
puts "  glbl:    ${out_dir}/glbl.v"

# ==============================================================================
# Step 2: 编译 + elaborate + 仿真 (用 XSim)
# ==============================================================================
puts "========================================"
puts "  Step 2: Compile with XSim"
puts "========================================"

# 编译 Verilog 文件
exec xvlog -prj ${work_dir}/postsim_xsim.prj 2>@1

puts "========================================"
puts "  Step 3: Elaborate"
puts "========================================"

# elaborate (加载 Xilinx 原语库)
exec xelab -L unisims_ver -L unimacro_ver -L xpm work.tb_lut_dtc_postsim glbl -s sim_postsim 2>@1

puts "========================================"
puts "  Step 4: Run simulation"
puts "========================================"

# 运行仿真
exec xsim sim_postsim -tclbatch ${work_dir}/xsim_run.tcl 2>@1

puts "========================================"
puts "  POST-SIM COMPLETE"
puts "========================================"
