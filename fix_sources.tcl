# ============================================================================
# fix_sources.tcl
# 修复 Vivado 项目源文件引用（文件移动后的路径更新）
# 在 Vivado Tcl console 中运行:  source fix_sources.tcl
# ============================================================================

set proj_dir [file dirname [info script]]/FPGA_SSC_PLL
set srcs_dir $proj_dir/FPGA_SSC_PLL.srcs

# 打开项目
open_project $proj_dir/FPGA_SSC_PLL.xpr

# ============================================================================
# 1. 移除不存在的源文件引用
# ============================================================================
set missing_files [list \
    "$proj_dir/../RTL/all/dtc_comp.v" \
    "$proj_dir/../RTL/all/fractionaln/dtc_ideal.v" \
    "$srcs_dir/sources_1/new/lut_dtc.v" \
    "$srcs_dir/sources_1/new/lut_dtc_top.v" \
    "$srcs_dir/sources_1/new/ssc_controller.v" \
    "$srcs_dir/sources_1/new/en_buf.v" \
    "$srcs_dir/sources_1/new/debug_clk.v" \
]

puts "=== 移除不存在的源文件引用 ==="
foreach f $missing_files {
    set norm_f [file normalize $f]
    if {[catch {remove_files $norm_f} err]} {
        puts "  跳过（可能已移除）: $norm_f"
    } else {
        puts "  已移除: $norm_f"
    }
}

# ============================================================================
# 2. 从 RTL 源码目录添加正确的文件
# ============================================================================
set rtl_dir "$proj_dir/../RTL/all"

puts "\n=== 添加源文件 ==="

# 添加 RTL/all/dtc/ 目录下所有源文件 (校准模块 + DTC 核心)
set dtc_files [glob -nocomplain [list $rtl_dir/dtc/*.v]]
foreach f $dtc_files {
    add_files -norecurse [list $f]
    set_property FILE_TYPE Verilog [get_files [list $f]]
    puts "  已添加: $f"
}

# 添加 ssc_controller.v (RTL/all/)
add_files -norecurse [list "$rtl_dir/ssc_controller.v"]
set_property FILE_TYPE Verilog [get_files [list "$rtl_dir/ssc_controller.v"]]
puts "  已添加: $rtl_dir/ssc_controller.v"

# ============================================================================
# 3. 确认所有必要的源码已存在
# ============================================================================
set expected_files [list \
    "$rtl_dir/fpga_ssc_pll_top.v" \
    "$rtl_dir/dtc/dtc_comp.v" \
    "$rtl_dir/dtc/lut_dtc.v" \
    "$rtl_dir/dtc/lut_dtc_top.v" \
    "$rtl_dir/ssc_controller.v" \
    "$rtl_dir/fractionaln/fractionaln.v" \
    "$rtl_dir/fractionaln/mash111.v" \
    "$rtl_dir/fractionaln/hk_efm.v" \
    "$rtl_dir/fractionaln/calculate_ps.v" \
    "$rtl_dir/fractionaln/dual_div.v" \
    "$rtl_dir/fractionaln/p_counter.v" \
    "$rtl_dir/fractionaln/s_counter.v" \
    "$rtl_dir/fractionaln/dff.v" \
    "$rtl_dir/fractionaln/div_2.v" \
    "$rtl_dir/fractionaln/div_45.v" \
    "$rtl_dir/fractionaln/div_89.v" \
    "$rtl_dir/fractionaln/efm.v" \
    "$rtl_dir/fractionaln/reg_async.v" \
    "$rtl_dir/fractionaln/reg_sync.v" \
]

puts "\n=== 检查所有源文件 ==="
set all_ok 1
foreach f $expected_files {
    set norm_f [file normalize $f]
    if {[file exists $norm_f]} {
        if {[llength [get_files -quiet $norm_f]] == 0} {
            add_files -norecurse [list $norm_f]
            puts "  ✓ 已添加: $norm_f"
        } else {
            puts "  ✓ 已存在: $norm_f"
        }
    } else {
        puts "  ✗ 不存在: $norm_f"
        set all_ok 0
    }
}

# ============================================================================
# 4. 保存项目
# ============================================================================
if {$all_ok} {
    puts "\n=== 所有源文件就绪，保存项目 ==="
} else {
    puts "\n=== 警告：部分文件缺失，请检查 ==="
}

save_project
close_project
puts "完成！"
