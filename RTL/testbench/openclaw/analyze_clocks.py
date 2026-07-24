# analyze_clocks.py — 从 VCD 提取 div_out_raw_g vs div_out_dtc_g 边沿时序
import re
import sys

vcd_file = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_force_clk.vcd"

# VCD 信号映射 (从 $dumpvars 注释获取)
# 5 = div_out_raw_g, 6 = div_out_dtc_g
# , = dtc_code, ' = comp_3rd
# ! = e_o_1, " = e_o_2, # = e_o_3
# $ = e3_r1, % = e3_r2, & = e3_r3

raw_val = 0
dtc_val = 0
raw_edges = []  # (time_ps, edge_type)
dtc_edges = []  # (time_ps, edge_type)
dtc_code = 0
comp_3rd = 0
in_dumpvars = False

with open(vcd_file, 'r', errors='ignore') as f:
    for line in f:
        line = line.strip()
        if line.startswith('#') or line.startswith('$'):
            if line.startswith('$enddefinitions'):
                break

with open(vcd_file, 'r', errors='ignore') as f:
    time_ps = 0
    for line in f:
        line = line.strip()
        if not line:
            continue
        if line.startswith('#'):
            time_ps = int(line[1:])
            continue
        if line.startswith('$'):
            continue
        
        # Signal changes
        if line == '05':  # div_out_raw_g = 0
            if raw_val != 0:
                raw_edges.append((time_ps, 'fall'))
                raw_val = 0
        elif line == '15':  # div_out_raw_g = 1
            if raw_val != 1:
                raw_edges.append((time_ps, 'rise'))
                raw_val = 1
        elif line == '06':  # div_out_dtc_g = 0
            if dtc_val != 0:
                dtc_edges.append((time_ps, 'fall'))
                dtc_val = 0
        elif line == '16':  # div_out_dtc_g = 1
            if dtc_val != 1:
                dtc_edges.append((time_ps, 'rise'))
                dtc_val = 1
        elif line == '04':  # locked_pll (signal 4)
            pass
        elif line == '14':  # locked_pll=1
            pass
        
        # Also track when we're past calibration done
        if time_ps > 2_000_000:  # After ~2us (cal done)
            break

# Also get the full VCD for post-calibration analysis
full_raw = []
full_dtc = []
full_code_time = []
full_comp_time = []

with open(vcd_file, 'r', errors='ignore') as f:
    time_ps = 0
    after_cal = False
    raw_v = 0
    dtc_v = 0
    code_v = 0
    
    for line in f:
        line = line.strip()
        if not line:
            continue
        if line.startswith('#'):
            time_ps = int(line[1:])
            continue
        if line.startswith('$'):
            continue
        
        if time_ps > 1_572_000 and not after_cal:  # cal done at ~1.572us
            after_cal = True
            raw_v = raw_val
            dtc_v = dtc_val
        
        if after_cal:
            if line == '05':
                if raw_v != 0:
                    full_raw.append((time_ps, 0))
                    raw_v = 0
            elif line == '15':
                if raw_v != 1:
                    full_raw.append((time_ps, 1))
                    raw_v = 1
            elif line == '06':
                if dtc_v != 0:
                    full_dtc.append((time_ps, 0))
                    dtc_v = 0
            elif line == '16':
                if dtc_v != 1:
                    full_dtc.append((time_ps, 1))
                    dtc_v = 1
            elif line.startswith('b') and line.endswith(','):
                # dtc_code
                val = int(line[1:-1], 2)
                full_code_time.append((time_ps, val))
            elif line.startswith("b") and line.endswith("'"):
                # comp_3rd
                val = int(line[1:-1], 2)
                full_comp_time.append((time_ps, val))

print("=" * 80)
print("CLOCK EDGE TIMING ANALYSIS (post-calibration, >1.572us)")
print("=" * 80)

# Extract rising edges only for period analysis
raw_rises = [(t, 'R') for t, e in full_raw if e == 1]
dtc_rises = [(t, 'R') for t, e in full_dtc if e == 1]
raw_falls = [(t, 'F') for t, e in full_raw if e == 0]
dtc_falls = [(t, 'F') for t, e in full_dtc if e == 0]

print(f"\nRaw clock (div_out_raw_g) edges: {len(raw_rises)} rises, {len(raw_falls)} falls")
print(f"DTC clock (div_out_dtc_g) edges: {len(dtc_rises)} rises, {len(dtc_falls)} falls")

# Period analysis (rising edge to next rising edge)
print("\n--- Rising Edge Periods (ps) ---")
print(f"{'Edge#':>6} {'Raw Rise(ps)':>14} {'DTC Rise(ps)':>14} {'Raw Period':>12} {'DTC Period':>12} {'Diff':>8} {'Code':>6}")
print("-" * 72)

min_count = min(len(raw_rises), len(dtc_rises))
for i in range(min_count):
    t_raw = raw_rises[i][0]
    t_dtc = dtc_rises[i][0]
    
    if i == 0:
        p_raw = 0
        p_dtc = 0
    else:
        p_raw = t_raw - raw_rises[i-1][0]
        p_dtc = t_dtc - dtc_rises[i-1][0]
    
    # Find dtc_code at this time
    code_at_edge = 0
    for ct, cv in full_code_time:
        if abs(ct - t_raw) < 2000:  # within 2ns
            code_at_edge = cv
    
    diff = t_dtc - t_raw
    print(f"{i:>6} {t_raw:>14} {t_dtc:>14} {p_raw:>12} {p_dtc:>12} {diff:>+8} {code_at_edge:>6}")

# Also check jitter: DTC period - ideal period
ideal_period = 113600  # 71 * 1.6ns = 113.6ns
print(f"\n--- Jitter Analysis (Period vs Ideal {ideal_period}ps) ---")
print(f"{'Edge#':>6} {'Raw Δ':>10} {'DTC Δ':>10}")
print("-" * 28)

for i in range(1, min_count):
    p_raw = raw_rises[i][0] - raw_rises[i-1][0]
    p_dtc = dtc_rises[i][0] - dtc_rises[i-1][0]
    j_raw = p_raw - ideal_period
    j_dtc = p_dtc - ideal_period
    print(f"{i:>6} {j_raw:>+10} {j_dtc:>+10}")

# Edge-to-edge delay (rising raw → rising dtc)
print(f"\n--- Raw→DTC Edge Delay ---")
print(f"{'Edge#':>6} {'Delay(ps)':>10}")
print("-" * 18)
for i in range(min_count):
    t_raw = raw_rises[i][0]
    t_dtc = dtc_rises[i][0]
    delay = t_dtc - t_raw
    print(f"{i:>6} {delay:>+10}")

# Summarize
print(f"\n--- Summary ---")
if min_count > 1:
    avg_j_raw = sum(raw_rises[i][0] - raw_rises[i-1][0] - ideal_period for i in range(1, min_count)) / (min_count - 1)
    avg_j_dtc = sum(dtc_rises[i][0] - dtc_rises[i-1][0] - ideal_period for i in range(1, min_count)) / (min_count - 1)
    max_j_raw = max(abs(raw_rises[i][0] - raw_rises[i-1][0] - ideal_period) for i in range(1, min_count))
    max_j_dtc = max(abs(dtc_rises[i][0] - dtc_rises[i-1][0] - ideal_period) for i in range(1, min_count))
    print(f"  Raw jitter:  avg={avg_j_raw:+.1f}ps, max={max_j_raw}ps")
    print(f"  DTC jitter:  avg={avg_j_dtc:+.1f}ps, max={max_j_dtc}ps")
    if max_j_dtc < max_j_raw:
        print(f"  ✅ DTC reduces jitter by {(1 - max_j_dtc/max_j_raw)*100:.0f}%")
    else:
        print(f"  ⚠️  DTC not reducing jitter (model limitation)")
