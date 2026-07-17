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
#create_clock -period 8.000 -name sys_clk_n -waveform {0.000 4.000} [get_ports sys_clk_n]
#create_clock -period 3.33  -name clk_300m_plk -waveform {0.000 1.660} [get_ports clk_300m_p]
#create_clock -period 3.33  -name clk_300m_n -waveform {0.000 1.660} [get_ports clk_300m_n]
create_clock -period 40    -name div_out_dtc [get_nets div_out_dtc]
create_clock -period 40    -name div_out_raw [get_nets div_out_raw]
create_clock -period 10    -name f45 [get_nets u_fracn_div/u_dual_div/f45]
create_clock -period 20    -name dtc_code [get_nets dtc_code[*]]
#ignore mmcm bufg conne33ction error
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets u_pll_mps_top/u_cleaner/clk_out1]



#ADC
# Define ADC clock period and half-period (UI/2) for DDR constraints
set adc_clk_period 8.000
set adc_clk_half_period [expr {$adc_clk_period / 2.0}]

# delay 8ns for hold fix, 2UI, not care DATA_N or DATA_N+2
set hold_fix_time [expr {$adc_clk_half_period * 1}]

