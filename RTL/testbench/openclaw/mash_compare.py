#!/usr/bin/env python3
"""
MASH 1-1-1 误差组合实验 v2
使用 hk_efm 的实际行为建模
"""
import numpy as np
import matplotlib.pyplot as plt

# ============================================================
# 参数
# ============================================================
WIDTH = 10
N_MAX = 1 << WIDTH       # 1024
FRACTION = 213           # 小数分频比 213/1024
N_SAMPLES = 10000

# ============================================================
# hk_efm 单级模型
# ============================================================
def hk_efm_stage(x_in, width, a_gain=1):
    """
    HK-EFM stage.
    sum = x_i + sum_r[WIDTH-1:0] - {A_GAIN{sum_r[WIDTH]}}
    e_o = sum_r[WIDTH-1:0]  (remainder, registered)
    y_o = sum_r[WIDTH]       (overflow, registered)
    """
    sum_r = 0
    max_val = 1 << width
    mask = max_val - 1
    
    y_out = np.zeros(len(x_in), dtype=np.int64)
    e_out = np.zeros(len(x_in), dtype=np.int64)
    
    for n in range(len(x_in)):
        rem = sum_r & mask           # sum_r[WIDTH-1:0]
        ovf = (sum_r >> width) & 1   # sum_r[WIDTH]
        
        # sum_clk.x = x_i + sum_r[WIDTH-1:0] - {A_GAIN{sum_r[WIDTH]}}
        s = int(x_in[n]) + rem - ovf * a_gain
        
        sum_r = s
        y_out[n] = (sum_r >> width) & 1
        e_out[n] = sum_r & mask
    
    return y_out, e_out

# ============================================================
# MASH 1-1-1 仿真
# ============================================================
x = np.full(N_SAMPLES, FRACTION, dtype=np.int64)

y1, e1 = hk_efm_stage(x, WIDTH, 1)
y2, e2 = hk_efm_stage(e1, WIDTH, 1)
y3, e3 = hk_efm_stage(e2, WIDTH, 1)

# delta_sigma (stage_sel=2'b01, first order only)
delta = y1

# ============================================================
# 对齐到 fractionaln.v 中的 negedge pipeline
# fractionaln.v (negedge Fout):
#   e1_r  <= Eo_raw;       // = e_o_1 延迟 (mash111.e_o = eo_d1 = e1[n-1])
#   e2_r2 <= e2_r1;        // e2[n-1]
#   e2_r3 <= e2_r2;        // e2[n-2]
#   e3_r2 <= e3_r1;        // e3[n-1]
#   e3_r3 <= e3_r2;        // e3[n-2]
#   e3_r4 <= e3_r3;        // e3[n-3]
#
# 在 negedge 域, comp_3rd 的值是:
#   e1_r + (e2_r2 - e2_r3) + (e3_r2 - 2*e3_r3 + e3_r4)
#   = e1[n-1] + (e2[n-1]-e2[n-2]) + (e3[n-1]-2*e3[n-2]+e3[n-3])
# ============================================================

def compute_errors(e1, e2, e3):
    n = len(e1)
    
    # Formula A: 现行代码
    #   e1[n-1] + (e2[n-1]-e2[n-2]) + (e3[n-1]-2*e3[n-2]+e3[n-3])
    err_a = np.zeros(n, dtype=np.float64)
    for i in range(3, n):
        err_a[i] = (e1[i-1]
                    + (e2[i-1] - e2[i-2])
                    + (e3[i-1] - 2*e3[i-2] + e3[i-3]))

    # Formula B1: 基于 e1 (第一级误差)
    #   e1[n] + e1[n-2] - 2*e1[n-1] + MID
    mid = 256
    err_b1 = np.zeros(n, dtype=np.float64)
    for i in range(2, n):
        err_b1[i] = e1[i] + e1[i-2] - 2*e1[i-1] + mid

    # Formula B3: 基于 e3 (第三级误差，用户最新公式)
    #   e3[n] + e3[n-2] - 2*e3[n-1] + MID
    err_b3 = np.zeros(n, dtype=np.float64)
    for i in range(2, n):
        err_b3[i] = e3[i] + e3[i-2] - 2*e3[i-1] + mid

    # Formula C: 仅 e1[n-1] + mid
    err_c = np.zeros(n, dtype=np.float64)
    for i in range(1, n):
        err_c[i] = e1[i-1] + mid

    # Formula D: 仅 e1[n-1] (无 offset)
    err_d = np.zeros(n, dtype=np.float64)
    for i in range(1, n):
        err_d[i] = e1[i-1]
    
    return err_a, err_b1, err_b3, err_c, err_d

err_a, err_b1, err_b3, err_c, err_d = compute_errors(e1, e2, e3)

# ============================================================
# 累积相位误差
# ============================================================
# 理想 Fout 周期 = N + Fraction/1024 (Fin 周期为单位)
# 实际 Fout 周期 = N + delta[n]
# 每拍相位误差 = Fraction/N_MAX - delta[n]  (归一化到 Fin 周期)
# 累积相位 = cumsum(每拍相位误差)

ideal = FRACTION / N_MAX
cum_raw = np.cumsum(ideal - delta)  # 无补偿

# 用误差信号补偿:
# DTC 补偿量 = err / N_MAX (归一化到 Fin 周期)
# 补偿后每拍相位误差 = (Fraction/N_MAX - delta[n]) + err[n]/N_MAX
# 但 err 已经是补偿量，直接加到相位上即可

# 对于 A: DTC 输出延迟变化 = err_a / N_MAX (Fin 周期为单位)
# 补偿后相位累积 = cumsum(ideal - delta + err_a/N_MAX)
# 但因为 err 和 delta 在同一拍，我们需要对齐时序

# 更准确: 补偿后的累积相位 = cumsum(ideal - delta) + cumsum(err/N_MAX)
# 但 err 已经是补偿目标，所以补偿后 residual = ideal - delta + err/N_MAX

# 检查相关性
print("=== 误差统计 (忽略前 20 拍) ===")
start = 20
for name, err in [("A(现行)", err_a), ("B1(基于e1)", err_b1), ("B3(基于e3)", err_b3), ("C(e1+mid)", err_c), ("D(e1)", err_d)]:
    print(f"  {name}:  mean={err[start:].mean():8.2f}  rms={np.std(err[start:]):8.2f}  "
          f"range={err[start:].max()-err[start:].min():8.2f}")

# 补偿后残余相位
residual_a = np.cumsum(ideal - delta[:len(err_a)] + err_a / N_MAX)
residual_b1 = np.cumsum(ideal - delta[:len(err_b1)] + err_b1 / N_MAX)
residual_b3 = np.cumsum(ideal - delta[:len(err_b3)] + err_b3 / N_MAX)
residual_c = np.cumsum(ideal - delta[:len(err_c)] + err_c / N_MAX)

print()
print("=== 补偿后残余累积相位误差 ===")
for name, res in [("无补偿", cum_raw), ("A(现行)", residual_a), ("B1(基于e1)", residual_b1), ("B3(基于e3)", residual_b3), ("C(e1+mid)", residual_c)]:
    print(f"  {name}:  rms={np.std(res[start:]):8.4f}  range={res[start:].max()-res[start:].min():8.4f}")

# ============================================================
# 频域分析
# ============================================================
fft_a = np.fft.fft(err_a[start:] - err_a[start:].mean())
fft_b1 = np.fft.fft(err_b1[start:] - err_b1[start:].mean())
fft_b3 = np.fft.fft(err_b3[start:] - err_b3[start:].mean())
freq = np.fft.fftfreq(len(err_a[start:]))

# 只显示低频部分 (前 10%)
half = len(freq)//2
cut = half // 10

print()
print("=== 低频分量能量 (前 10% 频谱) ===")
def lowfreq_power(err):
    fft = np.fft.fft(err[start:] - err[start:].mean())
    power = np.abs(fft[:cut])**2
    total = np.abs(fft[:half])**2
    return power.sum() / total.sum() * 100

print(f"  A(现行): 低频占比 = {lowfreq_power(err_a):.1f}%")
print(f"  B1(基于e1): 低频占比 = {lowfreq_power(err_b1):.1f}%")
print(f"  B3(基于e3): 低频占比 = {lowfreq_power(err_b3):.1f}%")

# ============================================================
# 绘图
# ============================================================
fig, axes = plt.subplots(3, 1, figsize=(14, 10), sharex=True)

t = np.arange(min(500, N_SAMPLES))
axes[0].plot(t, err_a[t], label='A (现行)', linewidth=1.5)
axes[0].plot(t, err_b1[t], '--', label='B1 (基于e1)', linewidth=1.5, alpha=0.8)
axes[0].plot(t, err_b3[t], '-.', label='B3 (基于e3)', linewidth=1.5, alpha=0.8)
axes[0].plot(t, err_c[t], ':', label='C (e1+mid)', linewidth=1.5, alpha=0.7)
axes[0].axhline(y=256, color='gray', linestyle=':', alpha=0.5)
axes[0].set_ylabel('误差值')
axes[0].set_title(f'MASH 1-1-1 误差对比 (F={FRACTION}/1024)')
axes[0].legend()
axes[0].grid(True, alpha=0.3)

# 差值
axes[1].plot(t, err_b3[t] - err_a[t], label='B3 - A', linewidth=1)
axes[1].plot(t, err_b3[t] - err_b1[t], '--', label='B3 - B1', linewidth=1, alpha=0.7)
axes[1].plot(t, err_b3[t] - err_c[t], ':', label='B3 - C', linewidth=1, alpha=0.7)
axes[1].axhline(y=0, color='gray', alpha=0.3)
axes[1].set_ylabel('差值')
axes[1].legend()
axes[1].grid(True, alpha=0.3)

# 补偿后累积相位
axes[2].plot(t, cum_raw[t[:len(t)]], label='无补偿', linewidth=1.5)
axes[2].plot(t, residual_a[t[:len(t)]], label='A补偿后', linewidth=1.5)
axes[2].plot(t, residual_b3[t[:len(t)]], '-.', label='B3补偿后', linewidth=1.5, alpha=0.8)
axes[2].set_xlabel('n')
axes[2].set_ylabel('累积相位误差')
axes[2].legend()
axes[2].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('mash_compare_v2.png', dpi=150)
print(f"\n图表已保存: mash_compare_v2.png")
plt.show()
