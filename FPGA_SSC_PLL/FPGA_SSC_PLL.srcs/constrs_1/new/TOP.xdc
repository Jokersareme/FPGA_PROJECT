# ============================================================================
# Automatically Generated XDC File from generate_final_mapping.py
# Created: 2026-01-23
# ============================================================================
#    input  wire sys_clk_p,      // 125MHz，必须来自 MMCM/BUFG
#    input  wire sys_clk_n,      // 125MHz，必须来自 MMCM/BUFG
#    input  wire sys_rst,
#    input  wire clk_300m_p,       // 300MHz，给 IDELAYCTRL，必须来自 MMCM/BUFG
#    input  wire clk_300m_n,       // 300MHz，给 IDELAYCTRL，必须来自 MMCM/BUFG
#    output wire sma_ref_p,      // 参考通道（无补偿）
#    output wire sma_ref_n,
#    output wire sma_dtc_p,      // 补偿通道（有 DTC）
#    output wire sma_dtc_n


set_property -dict {PACKAGE_PIN AV14 IOSTANDARD LVDS} [get_ports sma_ref_p]
set_property -dict {PACKAGE_PIN AV13 IOSTANDARD LVDS} [get_ports sma_ref_n]

set_property -dict {PACKAGE_PIN R32 IOSTANDARD LVDS} [get_ports sma_dtc_p]
set_property -dict {PACKAGE_PIN P32 IOSTANDARD LVDS} [get_ports sma_dtc_n]

#set_property -dict {PACKAGE_PIN AG9 IOSTANDARD LVDS} [get_ports sma_ref_p]
#set_property -dict {PACKAGE_PIN AG8 IOSTANDARD LVDS} [get_ports sma_ref_n]

#set_property -dict {PACKAGE_PIN F31 IOSTANDARD LVDS} [get_ports clk_300m_p]
#set_property -dict {PACKAGE_PIN G31 IOSTANDARD LVDS} [get_ports clk_300m_n]

set_property -dict {PACKAGE_PIN AY24 IOSTANDARD LVDS} [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN AY23 IOSTANDARD LVDS} [get_ports sys_clk_n]

set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS12} [get_ports sys_rst]

# ============================================================================
# timing constraints
# ============================================================================
#get_pins -hierarchical *cic_clkdiv*
create_clock -period 8.000 -name sys_clk_p -waveform {0.000 4.000} [get_ports sys_clk_p]
create_clock -period 1.600 -name clk_out_pll [get_nets clk_out_pll]
#create_clock -period 8.000 -name sys_clk_n -waveform {0.000 4.000} [get_ports sys_clk_n]
#create_clock -period 3.33  -name clk_300m_plk -waveform {0.000 1.660} [get_ports clk_300m_p]
#create_clock -period 3.33  -name clk_300m_n -waveform {0.000 1.660} [get_ports clk_300m_n]
create_clock -period 40    -name div_out_dtc [get_nets div_out_dtc]
create_clock -period 40    -name div_out_raw [get_nets div_out_raw]
create_clock -period 10    -name f45 [get_nets u_fracn_div/u_dual_div/f45]
create_clock -period 20    -name dtc_code [get_nets dtc_code[*]]
#ignore mmcm bufg conne33ction error
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets u_pll_mps_top/u_cleaner/clk_out1]

# ============================================================================
# DTC (CARRY8 delay chain) 时序约束
# CARRY8 作为可编程延迟链使用, CI→CO 是组合路径, 
# 设 false_path 避免 Vivado 将其作为关键路径处理.
# 精确到具体 cell hierarchy, 避免误伤其他 CARRY8.
# ============================================================================

# DTC 主路径 1 (u_lut_dtc_dly)
set_false_path -through [get_cells -hierarchical -filter {NAME =~ *lut_dtc_top/u_lut_dtc_dly/u_carry*}]
# DTC 主路径 2 (u_lut_dtc_dly2)
set_false_path -through [get_cells -hierarchical -filter {NAME =~ *lut_dtc_top/u_lut_dtc_dly2/u_carry*}]
# DTC 校准路径 (16 级 cascade)
set_false_path -through [get_cells -hierarchical -filter {NAME =~ *lut_dtc_top/cascade*/u_lut_dtc/u_carry*}]

# 保持 carry 链的 DONT_TOUFF 属性不被综合器优化
set_property BLOCK_SYNTH.COLLAPSE_ALL NONE [get_cells -hierarchical -filter {NAME =~ *lut_dtc_top*}]

# ============================================================================
# Pblock: 将所有 DTC CARRY8 约束在相邻 SLICE 区域
# 确保各 CARRY8 链之间物理靠近, 延迟特性一致.
#
# ⚠️ 请将 X0Ymin~X0Ymax 替换为目标芯片的实际坐标.
#    XCVU9P-FLGA2104-2L-E 参考:
#    - 一个 CLOCK_REGION 约 60 SLICEs 高
#    - 512-tap CARRY8 链需要 64 SLICEs (8 per CARRY8 × 64 CARRY8s)
#    - 建议预留至少 80 SLICEs 高度, 选在芯片中部 CLOCK_REGION
# ============================================================================
#create_pblock pblock_dtc
#add_cells_to_pblock pblock_dtc [get_cells -hierarchical -filter {NAME =~ *lut_dtc_top*}]
#resize_pblock pblock_dtc -add SLICE_X0Y100:SLICE_X0Y180


#ADC
# Define ADC clock period and half-period (UI/2) for DDR constraints
set adc_clk_period 8.000
set adc_clk_half_period [expr {$adc_clk_period / 2.0}]

# delay 8ns for hold fix, 2UI, not care DATA_N or DATA_N+2
set hold_fix_time [expr {$adc_clk_half_period * 1}]
