"""
mash_clock_compare.py — 数学生成 MASH111 误差，对比三时钟
方法同之前的 Python MASH 验证

三时钟:
  1. 理想时钟: Fout_ideal = Fin / Integer, 固定周期
  2. 实际分频时钟: Fout_actual = Fin / (Integer + delta_sigma[n])
     delta_sigma = MASH111 输出 (基于 Fraction 调制)
  3. 计算时钟: 理想边沿 + DTC 补偿
     comp_time = comp_3rd × gain / 2^SHIFT × TAP_PS
  其中 comp_3rd = e3[n] - 2*e3[n-1] + e3[n-2]
"""

import math

# ===== 配置参数 (与 FPGA 设计一致) =====
FIN_PS = 1600          # 625MHz VCO 周期 (ps)
INTEGER = 71           # 整数分频比
FRACTION = 213         # 小数部分 (10-bit, 213/1024 ≈ 0.208)
FRAC_WIDTH = 10
GAIN = 153             # 最佳增益 (从 comp_3rd vs ds 相关性分析得到)
SHIFT = 11
TAP_PS = 20            # CARRY8 tap 延迟
DTC_WIDTH = 9
MID = 256              # 3阶 DTC 中心偏移

# 每周期理想 Fout 周期
IDEAL_PERIOD_PS = FIN_PS * INTEGER  # 113600ps (8.8MHz)
print(f"Ideal Fout period: {IDEAL_PERIOD_PS}ps ({1e6/IDEAL_PERIOD_PS:.1f}MHz)")

# ===== MASH111 建模 =====
# MASH111: 三级 EFM 级联
# 每级: sum = x + sum_r - sum_r[WIDTH]  (A_GAIN=1 时)
# y_o = sum_r[WIDTH] (进位)
# e_o = sum_r[WIDTH-1:0] (余数)
# 输出: c2 = y1 + (y2 + y3 - y3_d) - (c1 - c1_d)
#      = y1 + y2 + y3 - y3_d - c1 + c1_d

class HkEfm:
    """hk_efm 行为模型"""
    def __init__(self, width=10):
        self.width = width
        self.sum_r = 0  # WIDTH+1 bits
    
    def step(self, x_i):
        """单步运行, 返回 (y_o, e_o)"""
        # sum = x_i + sum_r[WIDTH-1:0] - sum_r[WIDTH]
        carry = (self.sum_r >> self.width) & 1
        sum_val = x_i + (self.sum_r & ((1 << self.width) - 1)) - carry
        self.sum_r = sum_val & ((1 << (self.width + 1)) - 1)
        y_o = (self.sum_r >> self.width) & 1
        e_o = self.sum_r & ((1 << self.width) - 1)
        return y_o, e_o

class Mash111:
    """三级 MASH111"""
    def __init__(self, width=10):
        self.width = width
        self.efm1 = HkEfm(width)
        self.efm2 = HkEfm(width)
        self.efm3 = HkEfm(width)
        self.c0_reg = 0  # y3[n-1]
        self.c1_reg = 0  # c1[n-1]
        self.y2_d = 0
        self.y3_d = 0
        self.y3_dd = 0
        self.eo_d1 = 0
        self.stage_sel = 0  # 0 = full MASH111
    
    def step(self, x_i):
        """单步运行, 返回 (y_o, e1, e2, e3, delta_sigma)"""
        y1, e1 = self.efm1.step(x_i)
        y2, e2 = self.efm2.step(e1)
        y3, e3 = self.efm3.step(e2)
        
        # MASH111 输出组合
        c1 = y2 + y3 - self.c0_reg
        c2 = y1 + c1 - self.c1_reg
        
        # 输出选择
        if self.stage_sel == 0:
            y_o = c2  # full MASH111
        elif self.stage_sel == 1:
            y_o = y1  # 1st order only
        else:
            y_o = 0
        
        # 更新延迟寄存器
        self.c0_reg = y3
        self.c1_reg = c1
        self.y2_d = y2
        self.y3_d = y3
        self.y3_dd = self.y3_d
        self.eo_d1 = e1
        
        # delta_sigma = y_o (4-bit signed)
        ds = y_o & 0xF
        if ds & 8:
            ds -= 16
        
        return ds, e1, e2, e3

# ===== 运行 MASH111 仿真 =====
mash = Mash111(FRAC_WIDTH)

N_CYCLES = 5000  # 仿真周期数
results = []

for n in range(N_CYCLES):
    x_i = FRACTION
    ds, e1, e2, e3 = mash.step(x_i)
    results.append((ds, e1, e2, e3))

print(f"Generated {N_CYCLES} MASH111 cycles")
print(f"  delta_sigma range: [{min(r[0] for r in results)}, {max(r[0] for r in results)}]")
print(f"  e1 range: [{min(r[1] for r in results)}, {max(r[1] for r in results)}]")
print(f"  e3 range: [{min(r[3] for r in results)}, {max(r[3] for r in results)}]")

# ===== 计算三时钟 =====
# 1. 理想时钟: 固定周期
# 2. 实际分频时钟: Fin / (Integer + delta_sigma[n])
# 3. 计算时钟: 理想 + comp_time

ideal_edges = []   # 理想时钟上升沿时间 (ps)
actual_edges = []  # 实际分频时钟上升沿时间 (ps)
comp_edges = []    # 计算时钟上升沿时间 (ps)

# 第一边沿从 0 开始
t_ideal = 0
t_actual = 0

# 用于 comp_3rd 的 e3 流水线
e3_1 = 0  # e3[n]
e3_2 = 0  # e3[n-1]
e3_3 = 0  # e3[n-2]

for n in range(N_CYCLES):
    ds, e1, e2, e3 = results[n]
    
    # 理想时钟
    t_ideal += IDEAL_PERIOD_PS
    ideal_edges.append(t_ideal)
    
    # 实际分频时钟
    ratio = INTEGER + ds  # 分频比随 delta_sigma 变化
    period_ps = FIN_PS * ratio
    t_actual += period_ps
    actual_edges.append(t_actual)
    
    # 计算时钟: 补偿
    # 流水线更新 (模拟 negedge Fout 行为)
    e3_3 = e3_2
    e3_2 = e3_1
    e3_1 = e3
    
    # comp_3rd = e3[n] - 2*e3[n-1] + e3[n-2] = (1-z^-1)^2 * e3
    c3_signed = e3_1 - 2 * e3_2 + e3_3
    
    # 补偿时间
    # dtc_code = saturate(gain * comp_3rd >> SHIFT + MID + offset)
    mult = c3_signed * GAIN
    mult_shifted = mult >> SHIFT
    code_signed = mult_shifted + MID
    code = max(0, min(511, code_signed))
    
    # 延迟 = code × TAP_PS
    delay_ps = code * TAP_PS
    
    # 计算时钟边沿 = 实际分频边沿 + 上一周期补偿延迟
    # 硬件: comp_3rd[n]→dtc_code→Fout[n+1] 边沿延迟
    if n == 0:
        prev_delay = 0
    comp_edges.append(t_actual + prev_delay)
    prev_delay = delay_ps

# ===== 跳过前 100 个周期 (预热) =====
skip = 100
ideal_edges = ideal_edges[skip:]
actual_edges = actual_edges[skip:]
comp_edges = comp_edges[skip:]

# ===== 分析结果 =====
print(f"\n{'='*80}")
print(f"CLOCK COMPARISON (skipped first {skip} cycles)")
print(f"{'='*80}")

print(f"\n{'─'*80}")
print(f"{'Edge#':>6} {'Ideal(ps)':>12} {'Actual(ps)':>12} {'Comp(ps)':>12} {'IdealΔ':>10} {'ActualΔ':>10} {'CompΔ':>10}")
print(f"{'─'*80}")

for i in range(min(30, len(ideal_edges))):
    t_ideal = ideal_edges[i]
    t_actual = actual_edges[i]
    t_comp = comp_edges[i]
    d_ideal = t_ideal - (0 if i == 0 else ideal_edges[i-1])
    d_actual = t_actual - (0 if i == 0 else actual_edges[i-1])
    d_comp = t_comp - (0 if i == 0 else comp_edges[i-1])
    print(f"{i:>6} {t_ideal:>12} {t_actual:>12} {t_comp:>12} {d_ideal:>+10} {d_actual:>+10} {d_comp:>+10}")

# ===== 周期抖动分析 =====
print(f"\n{'='*80}")
print(f"PERIOD JITTER ANALYSIS (vs ideal {IDEAL_PERIOD_PS}ps)")
print(f"{'='*80}")

ideal_periods = [ideal_edges[i] - ideal_edges[i-1] for i in range(1, len(ideal_edges))]
actual_periods = [actual_edges[i] - actual_edges[i-1] for i in range(1, len(actual_edges))]
comp_periods = [comp_edges[i] - comp_edges[i-1] for i in range(1, len(comp_edges))]

ideal_jitter = [p - IDEAL_PERIOD_PS for p in actual_periods]
actual_jitter = [p - IDEAL_PERIOD_PS for p in actual_periods]
comp_jitter = [p - IDEAL_PERIOD_PS for p in comp_periods]

print(f"\n{'':>10} {'Ideal(ps)':>15} {'Actual(ps)':>15} {'Comp(ps)':>15}")
print(f"{'─'*55}")
print(f"{'Avg Period:':>10} {sum(ideal_periods)/len(ideal_periods):>15.1f} {sum(actual_periods)/len(actual_periods):>15.1f} {sum(comp_periods)/len(comp_periods):>15.1f}")
print(f"{'Max +Jitter:':>10} {max(ideal_jitter):>+15d} {max(actual_jitter):>+15d} {max(comp_jitter):>+15d}")
print(f"{'Max -Jitter:':>10} {min(ideal_jitter):>+15d} {min(actual_jitter):>+15d} {min(comp_jitter):>+15d}")
print(f"{'RMS Jitter:':>10} ", end="")
rms_i = math.sqrt(sum(j*j for j in ideal_jitter)/len(ideal_jitter))
rms_a = math.sqrt(sum(j*j for j in actual_jitter)/len(actual_jitter))
rms_c = math.sqrt(sum(j*j for j in comp_jitter)/len(comp_jitter))
print(f"{rms_i:>15.1f} {rms_a:>15.1f} {rms_c:>15.1f}")

# ===== 边缘偏移分析 =====
print(f"\n{'='*80}")
print(f"EDGE OFFSET (actual/computed - ideal)")
print(f"{'='*80}")

actual_offset = [actual_edges[i] - ideal_edges[i] for i in range(len(ideal_edges))]
comp_offset = [comp_edges[i] - ideal_edges[i] for i in range(len(ideal_edges))]

print(f"\n{'':>10} {'Actual(ps)':>15} {'Comp(ps)':>15}")
print(f"{'─'*42}")
print(f"{'Max +Off:':>10} {max(actual_offset):>+15d} {max(comp_offset):>+15d}")
print(f"{'Max -Off:':>10} {min(actual_offset):>+15d} {min(comp_offset):>+15d}")
print(f"{'RMS Off:':>10} ", end="")
rms_ao = math.sqrt(sum(o*o for o in actual_offset)/len(actual_offset))
rms_co = math.sqrt(sum(o*o for o in comp_offset)/len(comp_offset))
print(f"{rms_ao:>15.1f} {rms_co:>15.1f}")

# ===== 补偿效果 =====
print(f"\n{'='*80}")
print(f"COMPENSATION EFFECTIVENESS")
print(f"{'='*80}")

# The compensation should reduce the edge offset
# Actual offset = fracN modulation
# Comp offset = fracN modulation + DTC compensation
# Good compensation: |comp_offset| < |actual_offset|

improved = sum(1 for i in range(len(actual_offset)) 
              if abs(comp_offset[i]) < abs(actual_offset[i]))
total = len(actual_offset)

print(f"\n  Cycles with improved jitter: {improved}/{total} ({100*improved/total:.1f}%)")
print(f"  RMS jitter improvement: {rms_a:.1f}ps -> {rms_c:.1f}ps ({(1-rms_c/rms_a)*100:.1f}%)" if rms_a > 0 else "  N/A")

# Sample comparison
print(f"\n{'─'*80}")
print(f"{'Edge#':>6} {'Ideal(ps)':>12} {'Actual(ps)':>12} {'Comp(ps)':>12} {'Off_Act':>10} {'Off_Comp':>10}")
print(f"{'─'*80}")
for i in range(min(20, len(ideal_edges))):
    off_a = actual_offset[i]
    off_c = comp_offset[i]
    better = "✓" if abs(off_c) < abs(off_a) else "✗"
    print(f"{i:>6} {ideal_edges[i]:>12} {actual_edges[i]:>12} {comp_edges[i]:>12} {off_a:>+10d} {off_c:>+10d}  {better}")

# ===== 结论 =====
print(f"\n{'='*80}")
print(f"CONCLUSION")
print(f"{'='*80}")
print(f"""
Parameters:
  Fin = {1e6/FIN_PS:.1f}MHz ({FIN_PS}ps)
  Integer = {INTEGER}, Fraction = {FRACTION}/{1<<FRAC_WIDTH}
  Ideal Fout = {1e6/IDEAL_PERIOD_PS:.1f}MHz ({IDEAL_PERIOD_PS}ps)
  MASH111 Fout range: {1e6/(FIN_PS*(INTEGER+(-8))):.1f}~{1e6/(FIN_PS*(INTEGER+7)):.1f}MHz
  Gain = {GAIN}, SHIFT = {SHIFT}, Tap = {TAP_PS}ps

Compensation formula:
  comp_3rd[n] = e3[n] - 2*e3[n-1] + e3[n-2] = (1-z^-1)^2 * e3
  dtc_code = saturate(gain * comp_3rd >> SHIFT + MID)
  comp_time = dtc_code * {TAP_PS}ps

Results:
  Actual fracN jitter: RMS={rms_a:.1f}ps, Max={max(abs(j) for j in actual_jitter):.0f}ps
  Compensated jitter:  RMS={rms_c:.1f}ps, Max={max(abs(j) for j in comp_jitter):.0f}ps
  Improvement:         {(1-rms_c/rms_a)*100:.1f}% RMS
  Cycles improved:     {100*improved/total:.0f}%

三时钟对比:
  理想时钟 = Fin / Integer, 固定周期 {IDEAL_PERIOD_PS}ps
  实际时钟 = Fin / (Integer + delta_sigma), 周期变化 (±{max(abs(j) for j in actual_jitter):.0f}ps)
  计算时钟 = 理想边沿 + DTC补偿, 补偿后抖动 RMS={rms_c:.1f}ps
""")
