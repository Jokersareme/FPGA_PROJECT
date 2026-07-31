# eo_dly_sel_compare.py — 对比 eo_dly_sel 各值对补偿效果的影响
import numpy as np

TVCO = 1600; N_MAX = 1024; HALF = 512; W = 10
Nint = 71; Frac = 213; Tref = (Nint + Frac/N_MAX) * TVCO
n = 5000; warm = 50

def efm(frac, n):
    mask = (1<<W)-1; sr = 0
    y = np.zeros(n, dtype=np.int32); e = np.zeros(n, dtype=np.int32)
    for i in range(n):
        f = int(frac[i]) if hasattr(frac, '__len__') else int(frac)
        s = f + (sr & mask) - ((sr>>W) & 1)
        sr = s & ((1<<(W+1))-1)
        e[i] = sr & mask; y[i] = (sr>>W) & 1
    return y, e

y1, e1 = efm(Frac, n); y2, e2 = efm(e1, n); y3, e3 = efm(e2, n)
y2d = np.roll(y2, 1); y2d[0] = 0
y3d = np.roll(y3, 1); y3d[0] = 0
y3dd = np.roll(y3, 2); y3dd[0:2] = 0
ds = y1 + (y2-y2d) + (y3-2*y3d+y3dd)
actual = np.cumsum((Nint + ds).astype(np.float64)) * TVCO
ideal = np.arange(n, dtype=np.float64) * Tref
es3 = e3.astype(np.float64) - HALF

def sim_hw(eo, gain):
    """精确硬件 pipeline 仿真"""
    comp = np.zeros(n)
    e3pipe = [0,0,0,0,0]
    Ec = [0,0,0]
    prev_ec = 0
    
    for i in range(1, n):
        e3 = es3[i-1]
        e3pipe = [e3] + e3pipe[:-1]
        c3 = e3pipe[1] - 2*e3pipe[2] + e3pipe[3]
        
        if eo == 0: ec = c3
        elif eo == 1: Ec = [c3] + Ec[:-1]; ec = Ec[0]
        elif eo == 2: Ec = [c3] + Ec[:-1]; ec = Ec[1]
        else: Ec = [c3] + Ec[:-1]; ec = Ec[2]
        
        if i == 1:
            comp[i] = 0
        else:
            code = int(prev_ec * gain / 2048) + 256
            code = max(0, min(511, code))
            comp[i] = code * 20
        prev_ec = ec
    
    edge = actual + comp
    pj = np.diff(edge) - Tref
    seg = pj[warm:]
    s = np.std(seg - np.mean(seg))
    return s

print("=" * 55)
print("eo_dly_sel 对比 (GAIN=50, 硬件精确 pipeline)")
print("=" * 55)
print(f"{'eo_dly_sel':>10} {'RMS(ps)':>10} {'改善':>10}")
print("-" * 32)
ref = 2026.21
for eo in range(4):
    s = sim_hw(eo, 50)
    impr = ref/s if s > 0 else 0
    print(f"{eo:>10} {s:>10.1f} {impr:>9.1f}x")

print(f"\n各 eo_dly_sel 最佳 gain:")
for eo in range(4):
    best = (99999, 0)
    for g in [50, 75, 100, 121, 150, 160, 180, 200, 250, 300]:
        s = sim_hw(eo, g)
        if s < best[0]:
            best = (s, g)
    print(f"  eo={eo}: best_gain={best[1]}, std={best[0]:.1f}ps")

# 关键: 不量化不饱和不上MID, 只加delay
print(f"\n无量化/饱和/MID (理想 DTC):")
for eo in range(4):
    comp = np.zeros(n)
    e3pipe = [0,0,0,0,0]
    Ec = [0,0,0]
    prev_ec = 0
    for i in range(1, n):
        e3 = es3[i-1]
        e3pipe = [e3] + e3pipe[:-1]
        c3 = e3pipe[1] - 2*e3pipe[2] + e3pipe[3]
        if eo == 0: ec = c3
        elif eo == 1: Ec = [c3] + Ec[:-1]; ec = Ec[0]
        elif eo == 2: Ec = [c3] + Ec[:-1]; ec = Ec[1]
        else: Ec = [c3] + Ec[:-1]; ec = Ec[2]
        delay = prev_ec / N_MAX * TVCO
        comp[i] = delay if i > 1 else 0
        prev_ec = ec
    edge = actual + comp
    pj = np.diff(edge) - Tref
    s = np.std(pj[warm:] - np.mean(pj[warm:]))
    print(f"  eo={eo}: std={s:.1f}ps ({ref/s:.1f}x)")
