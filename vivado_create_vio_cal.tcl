# ============================================================================
# vivado_create_vio_cal.tcl
# 在 Vivado 中创建 vio_cal IP (校准控制用)
# 用法: Vivado Tcl Console → source vivado_create_vio_cal.tcl
# ============================================================================
#
# vio_cal 信号定义:
#   probe_out0: cal_start     (1-bit)  → 上升沿触发自动校准
#   probe_out1: cal_auto_en   (1-bit)  → 0=手动模式, 1=自动校准模式
#   probe_in0 : dtc_gain_cal  (10-bit) → 校准修正后的增益值
#   probe_in1 : cal_done      (1-bit)  → 校准完成标志
# ============================================================================

# 在 IP 目录下创建 vio_cal
create_ip -name vio -vendor xilinx.com -library ip -module_name vio_cal

set_property -dict [list \
    CONFIG.C_NUM_PROBE_OUT {3} \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT0_OPTION {0} \
    CONFIG.C_PROBE_OUT1_WIDTH {1} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT1_OPTION {0} \
    CONFIG.C_PROBE_OUT2_WIDTH {1} \
    CONFIG.C_PROBE_OUT2_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT2_OPTION {0} \
    CONFIG.C_NUM_PROBE_IN {2} \
    CONFIG.C_PROBE_IN0_WIDTH {10} \
    CONFIG.C_PROBE_IN1_WIDTH {1} \
] [get_ips vio_cal]

regenerate_ip [get_ips vio_cal]
puts "vio_cal IP created successfully"
