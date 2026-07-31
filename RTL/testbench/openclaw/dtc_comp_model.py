#!/usr/bin/env python3
"""
MASH 111 DTC 补偿精确仿真 v2
对比：理想补偿量 vs 各公式补偿量
"""
import numpy as np
import matplotlib.pyplot as plt

T_VCO_PS = 1600
T_HALF = T_VCO_PS // 2
N_INT = 50
FRAC = 256
N_MAX = 1024
N_CYCLES = 10000

def run_mash(n_cycles, frac, width=10):
    n_max = 1 << width; mask = n_max - 1
    sr1 = sr2 = sr3 = 0
    e1 = np.zeros(n_cycles, dtype=np.int64)
    e2 = np.zeros(n_cycles, dtype=np.int64)
    e3 = np.zeros(n_cycles, dtype=np.int64)
    delta = np.zeros(n_cycles, dtype=np.int64)
    for n in range(n_cycles):
        s1 = frac + (sr1 & mask) - ((sr1 >> width) & 1); sr1 = s1
        e1[n] = sr1 & mask; y1 = (sr1 >> width) & 1
        s2 = e1[n] + (sr2 & mask) - ((sr2 >> width) & 1); sr2 = s2
        e2[n] = sr2 & mask; y2 = (sr2 >> width) & 1
        s3 = e2[n] + (sr3 & mask) - ((sr3 >> width) & 1); sr3 = s3
        e3[n] = sr3 & mask; y3 = (sr3 >> width) & 1
        delta[n] = y1  # stage_sel=2'b01
    return e1, e2, e3, delta

e1, e2, e3, delta = run_mash(N_CYCLES, FRAC)

# 理想边沿与实际边沿
ideal = np.arange(N_CYCLES, dtype=np.float64) * (N_INT + FRAC/N_MAX) * T_VCO_PS / 2
actual = np.cumsum((N_INT + delta).astype(np.float64)) * T_HALF
phase_err = actual - ideal

# 理想补偿量 = -phase_err （加延迟往回推）
ideal_comp = -phase_err

# ============================================================
# MASH 公式补偿量
# ============================================================
STEP = T_VCO_PS / N_MAX  # 1.5625ps
mid = 256

# A: 现行
comp_a = np.zeros(N_CYCLES)
for i in range(3, N_CYCLES):
    comp_a[i] = e1[i-1] + (e2[i-1]-e2[i-2]) + (e3[i-1]-2*e3[i-2]+e3[i-3])

# B3: 基于 e3 的 (1-z⁻¹)²
comp_b3 = np.zeros(N_CYCLES)
for i in range(2, N_CYCLES):
    comp_b3[i] = e3[i] + e3[i-2] - 2*e3[i-1] + mid

# B1: 基于 e1 的 (1-z⁻¹)²
comp_b1 = np.zeros(N_CYCLES)
for i in range(2, N_CYCLES):
    comp_b1[i] = e1[i] + e1[i-2] - 2*e1[i-1] + mid

# 所有补偿量转换成 ps，并去掉 MID 固定偏置
def comp_to_ps(comp):
    return (comp - comp.mean()) * STEP

ca_ps = comp_to_ps(comp_a)
cb3_ps = comp_to_ps(comp_b3)
cb1_ps = comp_to_ps(comp_b1)

# ============================================================
# 相关性分析: 理想补偿 vs 各公式
# ============================================================
start = 50
seg_len = 2000
seg = slice(start, start+seg_len)

def corr(x, y):
    return np.corrcoef(x[seg], y[seg])[0, 1]

print(f"=== 理想补偿量与公式补偿量的相关性 (seg={seg_len} samples) ===")
print(f"{'':15s} {'corr':>7s} {'ideal_rms':>10s} {'formula_rms':>12s}")
print("-"*50)
for name, c_ps in [("A(现行)", ca_ps), ("B1(基于e1)", cb1_ps), ("B3(基于e3)", cb3_ps)]:
    r = corr(ideal_comp, c_ps)
    print(f"{name:15s} {r:7.3f} {np.std(ideal_comp[seg]):10.1f} {np.std(c_ps[seg]):12.1f}")

# 补偿后残余相位
res_a = phase_err + ca_ps
res_b1 = phase_err + cb1_ps
res_b3 = phase_err + cb3_ps
res_ideal = np.zeros_like(phase_err)  # 完美补偿

print(f"\n=== 补偿后残余相位误差 (ps) ===")
print(f"{'':15s} {'rms':>8s} {'p-p':>8s}")
print("-"*35)
for name, res in [("无补偿", phase_err), ("A", res_a), ("B1", res_b1), ("B3", res_b3)]:
    s = res[start:]
    print(f"{name:15s} {np.std(s):8.1f} {np.ptp(s):8.1f}")

# ============================================================
# 绘图
# ============================================================
fig, axes = plt.subplots(3, 1, figsize=(14, 10), sharex=True)
t = np.arange(seg_len)

axes[0].plot(t, ideal_comp[seg], 'k-', label='理想补偿', linewidth=2, alpha=0.8)
axes[0].plot(t, ca_ps[seg], label='A (现行)', linewidth=1.5, alpha=0.6)
axes[0].plot(t, cb1_ps[seg], '--', label='B1 (基于e1)', linewidth=1.5, alpha=0.7)
axes[0].plot(t, cb3_ps[seg], '-.', label='B3 (基于e3)', linewidth=1.5, alpha=0.8)
axes[0].set_ylabel('补偿量 (ps)')
axes[0].set_title(f'理想补偿 vs 公式补偿 (R={N_INT}+{FRAC}/{N_MAX})')
axes[0].legend(fontsize=9)
axes[0].grid(True, alpha=0.3)

# 残余相位
axes[1].plot(t, phase_err[seg], 'k-', label='无补偿', linewidth=1.5, alpha=0.4)
axes[1].plot(t, res_a[seg], label='A 补偿后', linewidth=1.5, alpha=0.6)
axes[1].plot(t, res_b1[seg], '--', label='B1 补偿后', linewidth=1.5, alpha=0.7)
axes[1].plot(t, res_b3[seg], '-.', label='B3 补偿后', linewidth=1.5, alpha=0.8)
axes[1].set_ylabel('残余相位 (ps)')
axes[1].legend(fontsize=9)
axes[1].grid(True, alpha=0.3)

# 直方图
axes[2].hist(phase_err[start:], bins=60, alpha=0.3, label='无补偿', density=True)
axes[2].hist(res_a[start:], bins=60, alpha=0.3, label='A', density=True)
axes[2].hist(res_b3[start:], bins=60, alpha=0.5, label='B3', density=True)
axes[2].set_xlabel('残余相位误差 (ps)')
axes[2].set_ylabel('概率密度')
axes[2].legend(fontsize=9)
axes[2].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('dtc_comp_v2.png', dpi=150)
print(f"\n图表已保存: dtc_comp_v2.png")
plt.show()
