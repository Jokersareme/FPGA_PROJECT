"""
Generate ideal_clk, Fout, E_combined waveform CSV
Python behavioral model matching verilog exactly
"""
import numpy as np
import csv, os

# Hardware params
TVCO = 1600          # ps
N_MAX = 1024
W = 10
Nint = 71
Frac = 213
N_SAMPLES = 2000     # enough cycles

# hk_efm (verilog exact)
class Efm:
    def __init__(self, w=10): self.w = w; self.sr = 0
    def step(self, x):
        c = (self.sr>>self.w)&1
        v = x + (self.sr&((1<<self.w)-1)) - c
        self.sr = v & ((1<<(self.w+1))-1)
        return (self.sr>>self.w)&1, self.sr&((1<<self.w)-1)

# MASH111
def run_mash(N):
    e = [Efm(W) for _ in range(3)]; c0 = c1 = 0
    ds = np.zeros(N, int)
    e3 = np.zeros(N, int)  # e3 = remainder - HALF (signed)
    HALF = 512
    for i in range(N):
        y1, e1 = e[0].step(Frac)
        y2, e2 = e[1].step(e1)
        y3, e3_ = e[2].step(e2)
        _c1 = y2 + y3 - c0; c2 = y1 + _c1 - c1
        c0, c1 = y3, _c1
        d = c2 & 0xF; d -= 16 if d & 8 else 0
        ds[i] = d
        e3[i] = e3_ - HALF
    return ds, e3

ds, e3 = run_mash(N_SAMPLES)

# Simulate pipeline: compute E_combined at each Fout cycle
# E_combined = e3[n] - 2*e3[n-1] + e3[n-2]
# This is comp_3rd in verilog: $signed({2'b0, e3_r2}) - $signed({1'b0, e3_r3, 1'b0}) + $signed({2'b0, e3_r4})
# Note verilog uses e3_r1,e3_r2,e3_r3 but in simulation they're shifted by 1
# From code: e3_r2 <= e3_r1; e3_r3 <= e3_r2; e3_r4 <= e3_r3
# So comp_3rd = e3[n-1] - 2*e3[n-2] + e3[n-3]
# And E_combined = comp_3rd (since eo_dly_sel=0, no extra delay)

# Actually re-reading: negedge Fout block:
# e3_r1 <= mash_e3 (e3[n]), e3_r2 <= e3_r1 (e3[n-1]), e3_r3 <= e3_r2 (e3[n-2])
# comp_3rd = e3_r2 - 2*e3_r3 + e3_r4  = e3[n-1] - 2*e3[n-2] + e3[n-3]

E_combined = np.zeros(N_SAMPLES)
for n in range(3, N_SAMPLES):
    val = e3[n-1] - 2*e3[n-2] + e3[n-3]
    # Saturate to 13-bit signed range
    if val > 4095: val = 4095
    if val < -4096: val = -4096
    E_combined[n] = val

# Generate timing:
# Fout period = (Nint + ds[n]) * TVCO
# Accumulate to get absolute times
fout_periods = (Nint + ds) * TVCO  # ps
fout_times = np.cumsum(fout_periods)  # ps

# ideal_clk = 125MHz = 8000ps period
ICLK_PERIOD = 8000  # ps
n_clks = int(fout_times[-1] / ICLK_PERIOD) + 100

# Build CSV: only last 80us (80000ps... wait, 80us = 80000000ps)
# Actually the sim runs for N_SAMPLES * avg_period ~ 2000 * 114ns = 228us
# Last 80us starts at ~148us
total_time = fout_times[-1]
start_time = total_time - 80000000  # last 80us in ps

csv_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\mash3_waveform.csv"

with open(csv_path, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['time_ps', 'time_us', 'ideal_clk', 'Fout', 'E_combined', 'edge_type'])
    
    # ideal_clk rising edges
    clk_t = start_time - (start_time % ICLK_PERIOD)
    while clk_t < total_time:
        clk_t += ICLK_PERIOD
        if clk_t > total_time: break
        # Find Fout value at this time
        fout_val = '0'
        for ft in fout_times:
            if abs(ft - clk_t) < 100:  # within 100ps
                fout_val = '1'
                break
            if ft > clk_t:
                break
        # Find E_combined at the LAST Fout edge before this time
        ec_val = '0'
        for ei, ft in enumerate(fout_times):
            if ft > clk_t - 5000:  # look at Fout edges near this time
                if ei > 0:
                    ec_val = str(int(E_combined[ei-1]))
                break
        
        w.writerow([int(clk_t), f"{clk_t/1e6:.3f}", '1', fout_val, ec_val, 'ideal_clk_rise'])
    
    w.writerow([])
    w.writerow(['=== Fout rising edges (last 80us) ==='])
    w.writerow(['time_ps', 'time_us', 'ideal_clk', 'Fout', 'E_combined', 'edge_type'])
    
    # Fout rising edges
    for ei in range(len(fout_times)):
        ft = fout_times[ei]
        if ft < start_time or ft > total_time:
            continue
        # ideal_clk value at this time
        iclk_val = '1' if ((int(ft) // ICLK_PERIOD) % 2 == 0) else '0'
        ec_val = str(int(E_combined[ei]))
        
        w.writerow([int(ft), f"{ft/1e6:.3f}", iclk_val, '1', ec_val, 'Fout_rise'])

size = os.path.getsize(csv_path)
print(f"Written: {csv_path} ({size/1024:.0f} KB)")
print(f"Total_time: {total_time/1e6:.1f}us")
print(f"ideal_clk edges: ~{n_clks}")
print(f"Fout edges in last 80us: ~{np.sum(fout_times > start_time)}")

# Sample output
print("\n=== First 5 ideal_clk edges ===")
with open(csv_path, 'r') as f:
    for i, line in enumerate(f):
        if i >= 7: break
        print(f"  {line.strip()}")
