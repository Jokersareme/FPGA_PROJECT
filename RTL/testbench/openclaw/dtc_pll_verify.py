"""
dtc_pll_verify.py — 贴合硬件的 MASH111+DTC 验证
参数: 与 fpga_ssc_pll_top.v / fractionaln.v / dtc_comp.v 一致
"""
import numpy as np

# ===== 硬件参数 =====
TVCO = 1600; N_MAX = 1024; W = 10; HALF = 512
Nint = 71; Frac = 213
TAP = 20; SHIFT = 11; DMAX = 511; MID = 256
# 理论最优增益: GAIN = TVCO * 2^SHIFT / (TAP * N_MAX) = 160
GAIN = 160

# ===== hk_efm (verilog精确) =====
class Efm:
    def __init__(self, w=10): self.w = w; self.sr = 0
    def step(self, x):
        c = (self.sr>>self.w)&1
        v = x + (self.sr&((1<<self.w)-1)) - c
        self.sr = v & ((1<<(self.w+1))-1)
        return (self.sr>>self.w)&1, self.sr&((1<<self.w)-1)

# ===== MASH111 (verilog精确) =====
def run_mash(N):
    e = [Efm(W) for _ in range(3)]; c0 = c1 = 0
    ds = np.zeros(N, int); e3 = np.zeros(N, float)
    for i in range(N):
        y1, e1 = e[0].step(Frac)
        y2, e2 = e[1].step(e1)
        y3, e3_ = e[2].step(e2)
        _c1 = y2 + y3 - c0; c2 = y1 + _c1 - c1
        c0, c1 = y3, _c1
        d = c2 & 0xF; d -= 16 if d & 8 else 0
        ds[i] = d; e3[i] = e3_ - HALF
    return ds, e3

ds, es3 = run_mash(5000)

# ===== 硬件精确 pipeline =====
def sim(eo_start, eo_sel, gain):
    """完整 pipeline:
       posedge N: MASH->ds[N], e3[N]
       negedge N: e3_r1<=e3[N], comp_3rd=..., E_combined<=...
       posedge N+1: dtc_code_pipe<=code(E_combined)
       negedge dtc_out: dtc_code_d1<=dtc_code_pipe -> delay edge N+2
    """
    ea = np.cumsum((Nint + ds).astype(float)) * TVCO
    ec = np.zeros(5000)
    e3r = [0.0]*6; Ec = [0.0]*3
    code_pipe = 0     # dtc_code_pipe (posedge)
    code_d1 = 0       # dtc_code_d1 (negedge)
    
    for n in range(5000):
        e3r = [es3[n]] + e3r[:-1]
        # negedge: c3 from e3_r1/r2/r3 (or r2/r3/r4)
        if eo_start == 0:
            c3 = e3r[0] - 2*e3r[1] + e3r[2]
        else:
            c3 = e3r[1] - 2*e3r[2] + e3r[3]
        # E_combined: eo_sel
        if eo_sel == 0: ec_ = c3
        else: Ec = [c3] + Ec[:-1]; ec_ = Ec[eo_sel-1]
        # posedge: dtc_code_pipe <= code
        code = int(ec_ * gain / (1<<SHIFT)) + MID
        code = max(0, min(DMAX, code))
        # 当前边沿用 dtc_code_d1 (来自2周期前)
        ec[n] = ea[n] + code_d1 * TAP
        # 流水线: code_pipe -> code_d1 (negedge dtc_out)
        code_d1 = code_pipe
        code_pipe = code
    
    pj = np.diff(ec[200:]) - Nint*TVCO
    return np.std(pj - np.mean(pj))

# ===== 结果 =====
gs = [50, 75, 100, 121, 150, 160, 180, 200, 250]
print("="*60)
print("  DTC PLL 验证 — 硬件精确 pipeline")
print(f"  Nint={Nint} Frac={Frac} TAP={TAP}ps GAIN={GAIN}")
print("="*60)
print(f"\n{'配置':>10} {'最佳gain':>8} {'std(ps)':>8} {'改善':>8}")
print("-"*40)
for lb, es, ee in [('r1+eo0',0,0),('r1+eo1',0,1),('r2+eo0',1,0),('r2+eo1',1,1)]:
    best = (99999, 0)
    for g in gs:
        s = sim(es, ee, g)
        if s < best[0]: best = (s, g)
    imp = (2077/best[0]-1)*100
    print(f"{lb:>10}  {best[1]:>4}    {best[0]:>6.0f}   {imp:>+7.1f}%")

s0 = sim(0,0,0)
print(f"{'无补偿':>10}  {'-':>4}    {s0:>6.0f}   {'-':>8}")

# 理论极限 (0-cycle lag, 无量化)
ds2, es3_ = run_mash(5000)
ea = np.cumsum((Nint + ds2).astype(float)) * TVCO
c3 = np.zeros(5000)
for i in range(2,5000):
    c3[i] = (es3_[i] - 2*es3_[i-1] + es3_[i-2]) / N_MAX * TVCO
eg = ea + c3; pj = np.diff(eg[200:]) - Nint*TVCO
print(f"{'理论极限':>10}  {'-':>4}    {np.std(pj-np.mean(pj)):>6.0f}   {2077/np.std(pj-np.mean(pj)):>6.0f}x")

print(f"\npipeline跟踪:")
print(f"  posedge N:     MASH -> ds[N], e3[N]")
print(f"  negedge N:     e3_r1<=e3[N], comp_3rd, E_combined")
print(f"  posedge N+1:   dtc_code_pipe<=code")
print(f"  negedge dtc:   dtc_code_d1<=code_pipe -> delay edge N+2")
print(f"")
print(f"  边沿 N+2 周期误差来自 ds[N] (经过d1+calc_ps+p_counter)")
print(f"  边沿 N+2 补偿用 c3[N] (同周期!)")
print(f"  -> 理论对齐正确, 但实际补偿量受gain/量化/sat限制")
