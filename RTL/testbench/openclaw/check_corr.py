# check_correlation.py — 检查 ds vs c3 的方向
import math
FIN_PS = 1600; INTEGER = 71; FRAC_WIDTH = 10
GAIN = 992; SHIFT = 11; TAP_PS = 20; FRACTION = 213

class HkEfm:
    def __init__(self, w=10): self.s=0; self.w=w
    def step(self, x):
        c = (self.s>>self.w)&1
        v = x + (self.s&((1<<self.w)-1)) - c
        self.s = v & ((1<<(self.w+1))-1)
        return (self.s>>self.w)&1, self.s&((1<<self.w)-1)

m = [HkEfm(FRAC_WIDTH) for _ in range(3)]
c0 = c1 = 0

ds_list = []; e3_list = []; c3_list = []
e3_1 = e3_2 = e3_3 = 0

for n in range(500):
    y1, e1 = m[0].step(FRACTION)
    y2, e2 = m[1].step(e1)
    y3, e3 = m[2].step(e2)
    _c1 = y2 + y3 - c0
    c2 = y1 + _c1 - c1
    c0, c1 = y3, _c1
    ds = c2 & 0xF
    if ds & 8: ds -= 16
    
    e3_3, e3_2, e3_1 = e3_2, e3_1, e3
    c3 = e3_1 - 2*e3_2 + e3_3
    
    ds_list.append(ds); e3_list.append(e3); c3_list.append(c3)

# Skip first 100 for warmup
skip = 100
ds_arr = ds_list[skip:]
c3_arr = c3_list[skip:]

print("ds vs comp_3rd correlation (post-warmup):")
print(f"{'n':>4} {'ds':>4} {'e3':>6} {'c3':>8} {'c3_chg':>10} {'needed_delay_chg':>16}")
print("-" * 52)

# needed delay change = -period_change = -ds * FIN_PS
for i in range(20):
    n = i + skip
    c3_chg = c3_list[n] - c3_list[n-1]
    dd = int(c3_chg * GAIN * TAP_PS / (1 << SHIFT))
    needed = -ds_list[n] * FIN_PS
    print(f"{n:>4} {ds_list[n]:>4} {e3_list[n]:>6} {c3_list[n]:>+8} {c3_chg:>+10} {dd:>+8} (need {needed:>+5})")

# Check: does delay change correlate with needed?
print()
corr_ds_c3 = sum(ds_arr[i]*c3_arr[i] for i in range(len(ds_arr)))/len(ds_arr)
corr_ds_c3chg = sum(ds_arr[i]*(c3_arr[i]-c3_arr[i-1]) for i in range(1,len(ds_arr)))/len(ds_arr)
print(f"Correlation ds * comp_3rd:     {corr_ds_c3:.1f}  (positive = bad sign)")
print(f"Correlation ds * d(comp_3rd):  {corr_ds_c3chg:.1f}")

# Delay delta
dd_arr = [(c3_arr[i]-c3_arr[i-1])*GAIN*TAP_PS/(1<<SHIFT) for i in range(1,len(c3_arr))]
need_arr = [-ds_arr[i]*FIN_PS for i in range(1, len(ds_arr))]

corr_dd_need = sum(dd_arr[i]*need_arr[i] for i in range(len(dd_arr)))/len(dd_arr)
print(f"Correlation delay_delta * needed: {corr_dd_need:.1f}  (positive = works)")

# Some sample
print(f"\nSample: ds=3 (period +4800ps):")
for i in range(skip, skip+200):
    if ds_list[i] == 3:
        n = i
        c3_chg = c3_list[n] - c3_list[n-1]
        dd = c3_chg * GAIN * TAP_PS / (1 << SHIFT)
        print(f"  n={n}: ds={ds_list[n]}, c3={c3_list[n]:+d}, chg={c3_chg:+d}, delay_delta={dd:.1f}ps, needed={-FIN_PS*3}ps")
        break

print(f"\nSample: ds=-3 (period -4800ps):")
for i in range(skip, skip+200):
    if ds_list[i] == -3:
        n = i
        c3_chg = c3_list[n] - c3_list[n-1]
        dd = c3_chg * GAIN * TAP_PS / (1 << SHIFT)
        print(f"  n={n}: ds={ds_list[n]}, c3={c3_list[n]:+d}, chg={c3_chg:+d}, delay_delta={dd:.1f}ps, needed={-FIN_PS*(-3)}ps")
        break
