###############################################################################
# idelay_dtc_top 约束 (idelay_dtc_top_opt.v : fabric 链 + UPDATE_MODE=SYNC)
###############################################################################
# 本模块 CASCADE="NONE"、DATAOUT->DATAIN 链式，不走专用 CASC 走线，
# 因此【不需要任何 IDELAYE3 的 LOC / 相邻布局约束】，也不会触发 Route 35-19。

# 唯一需要的约束：给 IDELAYE3 控制时钟 idelay_clk 加周期约束（SYNC 对齐两级的关键）
# ★ 若工程已在别处对 idelay_clk 做过 create_clock，这一条可省略，不要重复加。
create_clock -name idelay_clk -period 8.000 [get_ports idelay_clk]   ; # 125 MHz = 8 ns

# ==================== 不要做的事 ====================
# 1) 不要写任何 set_property LOC IDELAY_XxYx ... main_delay[?].u_idelay
#    （fabric 链无需相邻 BITSLICE，强锁还可能与真实 IO 引脚冲突）
# 2) 不要加 IDELAYCTRL 实例 / REFCLK 约束 (COUNT 模式 EN_VTC=0，无物理 REFCLK)
# 3) 之前那份 idelay_cascade_constraints.xdc(带 CASC LOC) 如果并进工程 XDC，请删除
