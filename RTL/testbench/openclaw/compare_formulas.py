# compare_formulas.py — 对比 (1-z^-1)^2 vs (1-z^-1)^3 补偿效果
import math

FIN_PS = 1600; INTEGER = 71; FRAC_WIDTH = 10
FRACTION = 213; TAP_PS = 20; SHIFT = 11; MID = 256

class E:
    def __init__(self,w=10): self.s=0;self.w=w
    def step(self,x):
        c=(self.s>>self.w)&1;v=x+(self.s&((1<<self.w)-1))-c
        self.s=v&((1<<(self.w+1))-1);return(self.s>>self.w)&1,self.s&((1<<self.w)-1)

m=[E(10) for _ in range(3)];c0=c1=0
ds_l=[];e1_l=[];e2_l=[];e3_l=[]
for n in range(5000):
    y1,e1=m[0].step(FRACTION);y2,e2=m[1].step(e1);y3,e3=m[2].step(e2)
    _c1=y2+y3-c0;c2=y1+_c1-c1;c0,c1=y3,_c1
    ds=c2&0xF;ds-=16 if ds&8 else 0
    ds_l.append(ds);e1_l.append(e1);e2_l.append(e2);e3_l.append(e3)

# 三时钟: 理想 / 实际 / 补偿后
# 用两种补偿公式对比

def evaluate_comp(comp_func, name, skip=100, N=4800):
    """comp_func(e3_hist) returns compensation value"""
    e3_pipe = [0]*4  # e3[n], e3[n-1], e3[n-2], e3[n-3]
    
    ideal_edges = [0]
    actual_edges = [0]
    comp_edges = [0]
    
    for n in range(N + skip):
        ds = ds_l[n]
        e3 = e3_l[n]
        
        # Shift pipeline
        e3_pipe = [e3] + e3_pipe[:-1]
        
        # Ideal clock
        ideal_edges.append(ideal_edges[-1] + FIN_PS * INTEGER)
        
        # Actual clock
        ratio = INTEGER + ds
        actual_edges.append(actual_edges[-1] + FIN_PS * ratio)
        
        # Compensated clock: actual + comp from PREVIOUS cycle
        # Compute compensation based on PREVIOUS cycle's e3
        if n > 0:
            comp_val = comp_func(e3_pipe[1], e3_pipe[2], e3_pipe[3], e3_pipe[0])
        else:
            comp_val = 0
        
        # Convert comp value to delay in ps
        code = int(comp_val * GAIN / (1 << SHIFT)) + MID
        code = max(0, min(511, code))
        delay_ps = code * TAP_PS
        
        # Use PREVIOUS cycle's delay for current edge
        if n == 0:
            comp_edges.append(actual_edges[-1])
        else:
            comp_edges.append(actual_edges[-1] + prev_delay)
        prev_delay = delay_ps
    
    # Trim warmup
    ideal = ideal_edges[skip+1:]
    actual = actual_edges[skip+1:]
    comp = comp_edges[skip+1:]
    
    # Period jitter
    periods_actual = [actual[i]-actual[i-1] for i in range(1,len(actual))]
    periods_comp = [comp[i]-comp[i-1] for i in range(1,len(comp))]
    
    rms_actual = math.sqrt(sum((p-FIN_PS*INTEGER)**2 for p in periods_actual)/len(periods_actual))
    rms_comp = math.sqrt(sum((p-FIN_PS*INTEGER)**2 for p in periods_comp)/len(periods_comp))
    
    max_actual = max(abs(p-FIN_PS*INTEGER) for p in periods_actual)
    max_comp = max(abs(p-FIN_PS*INTEGER) for p in periods_comp)
    
    print(f"\n{'='*60}")
    print(f"  {name}")
    print(f"{'='*60}")
    print(f"  {'Metric':>20} {'Actual':>12} {'Compensated':>12} {'Improvement':>12}")
    print(f"  {'-'*56}")
    print(f"  {'RMS Jitter(ps):':>20} {rms_actual:>12.1f} {rms_comp:>12.1f} {(1-rms_comp/rms_actual)*100:>+11.1f}%")
    print(f"  {'Max +Jitter(ps):':>20} {max_actual:>12.0f} {max_comp:>12.0f} {(1-max_comp/max_actual)*100:>+11.1f}%")
    
    return rms_comp

# ===== 尝试不同补偿公式和增益 =====
# 测试多种 gain 找到最优

def test_comp(comp_func, name, gains=None):
    if gains is None:
        gains = [10, 20, 30, 50, 75, 100, 121, 150, 200, 300, 500, 1000]
    
    global GAIN
    print(f"\n{'='*60}")
    print(f"  Testing: {name}")
    print(f"{'='*60}")
    print(f"  {'Gain':>6} {'RMS(ps)':>10}")
    print(f"  {'-'*18}")
    
    best_rms = float('inf')
    best_gain = 0
    
    for g in gains:
        GAIN = g
        rms = evaluate_comp(comp_func, name, skip=200, N=4000)
        print(f"  {g:>6} {rms:>10.1f}")
        if rms < best_rms:
            best_rms = rms
            best_gain = g
    
    print(f"  {'─'*18}")
    print(f"  {'BEST:':>6} {best_gain:>6} {best_rms:>10.1f}")
    return best_gain, best_rms

# Formula 1: (1-z^-1)^2 = e3[n] - 2*e3[n-1] + e3[n-2]
def comp_2nd(e3_n1, e3_n2, e3_n3, e3_n):
    """(1-z^-1)^2: uses c3[n], c3[n-1]"""
    # We need comp based on c3[n-1] = e3_n1 - 2*e3_n2 + e3_n3
    return e3_n1 - 2*e3_n2 + e3_n3

# Formula 2: (1-z^-1)^3 = e3[n] - 3*e3[n-1] + 3*e3[n-2] - e3[n-3]
def comp_3rd_power(e3_n1, e3_n2, e3_n3, e3_n):
    """(1-z^-1)^3 = e3[n-1] - 3*e3[n-2] + 3*e3[n-3] - e3[n-4]"""
    # We receive: e3_n1 = e3[n-1], e3_n2 = e3[n-2], e3_n3 = e3[n-3]
    # But we don't have e3[n-4] in the 4-stage pipe...
    # e3_n = e3[n], so we need one more delay
    # For now use: e3_n1 - 3*e3_n2 + 3*e3_n3 - (some_earlier)
    # Actually, let me compute from e3[n] to e3[n-3]
    return e3_n - 3*e3_n1 + 3*e3_n2 - e3_n3

# Formula 3: Just e3 (1st order)
def comp_1st(e3_n1, e3_n2, e3_n3, e3_n):
    return e3_n1

# Formula 4: (1-z^-1) * e3 = e3[n] - e3[n-1]
def comp_1st_diff(e3_n1, e3_n2, e3_n3, e3_n):
    """(1-z^-1)"""
    return e3_n1 - e3_n2

print("=" * 60)
print("  COMPARING DTC COMPENSATION FORMULAS")
print("  For MASH111 noise = (1-z^-1)^3 * e3")
print("=" * 60)

print("\n\n--- Testing (1-z^-1)^2 (CURRENT) ---")
print("comp = e3[n-1] - 2*e3[n-2] + e3[n-3]")
g2, r2 = test_comp(comp_2nd, "(1-z^-1)^2", [50, 75, 100, 121, 140, 150, 160, 170, 180, 200, 250, 300])

print("\n\n--- Testing (1-z^-1)^3 ---")
print("comp = e3[n] - 3*e3[n-1] + 3*e3[n-2] - e3[n-3]")
g3, r3 = test_comp(comp_3rd_power, "(1-z^-1)^3", [50, 75, 100, 121, 140, 150, 160, 180, 200, 250, 300, 500])

print("\n\n--- Testing no compensation ---")
g0, r0 = test_comp(lambda *a: 0, "No compensation", [0])

print("\n\n--- Testing e3 (1st order) ---")
g1, r1 = test_comp(comp_1st, "e3 (1st order)", [50, 75, 100, 121, 140, 150, 160, 180, 200, 250])

print("\n\n--- Testing (1-z^-1) * e3 ---")
gd, rd = test_comp(comp_1st_diff, "(1-z^-1) * e3", [50, 75, 100, 121, 140, 150, 160, 180, 200, 250])

print("\n" + "=" * 60)
print("  FINAL COMPARISON")
print("=" * 60)
print(f"  {'Formula':>25} {'Best Gain':>10} {'RMS(ps)':>10}")
print(f"  {'-'*47}")
print(f"  {'No compensation':>25} {'-':>10} {r0:>10.1f}")
print(f"  {'e3 (1st order)':>25} {g1:>10} {r1:>10.1f}")
print(f"  {'(1-z^-1) * e3':>25} {gd:>10} {rd:>10.1f}")
print(f"  {'(1-z^-1)^2 * e3 (CURRENT)':>25} {g2:>10} {r2:>10.1f}")
print(f"  {'(1-z^-1)^3 * e3':>25} {g3:>10} {r3:>10.1f}")
