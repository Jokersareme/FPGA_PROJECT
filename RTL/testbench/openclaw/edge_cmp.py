"""Compare ideal_clk, div_out_raw, div_out_dtc rising edges"""
import re, os, csv

vcd = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"
csv_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\edge_compare.csv"

with open(vcd, 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Signal IDs
# ideal_clk  = '&'
# div_out_raw = 'Q'  (u_sys_bufg_fracn_out.I)
# div_out_dtc = 'S' (u_sys_bufg_4.I)
# div_out_dtc_g = 'R' (u_sys_bufg_4.O)
# carry_dout = 'i$'

signals = {
    '&': 'ideal_clk',
    'Q': 'div_out_raw',
    'S': 'div_out_dtc',
}

# Parse VCD for rising edges
time = 0
cur = {idc: 'x' for idc in signals}
prev = {idc: 'x' for idc in signals}
edges = {name: [] for name in signals.values()}

i = 0
while i < len(body):
    c = body[i]
    if c == '#':
        j = i + 1
        while j < len(body) and body[j].isdigit():
            j += 1
        if j > i + 1:
            time = int(body[i+1:j])
        i = j
    elif c in '01xz':
        val = c
        i += 1
        if i < len(body):
            j = i
            while j < len(body) and body[j].isprintable() and body[j] not in ' \t\r\n#b':
                j += 1
            id_str = body[i:j]
            i = j
            if id_str in signals:
                cur[id_str] = val
                if val == '1' and prev[id_str] != '1':
                    edges[signals[id_str]].append(time)
                prev[id_str] = val
    else:
        i += 1

print("Rising edges found:")
for name, times in edges.items():
    print(f"  {name}: {len(times)} edges")

# Export to CSV
import numpy as np
# Get the last ~80us of data
max_time = max(t for times in edges.values() for t in times) if any(edges.values()) else 0
start_time = max_time - 80000000  # last 80us in ps

print(f"\nLast 80us comparison (from {start_time/1e6:.1f}us to {max_time/1e6:.1f}us):")
print()

# For each div_out_raw edge, find nearest ideal_clk edge and div_out_dtc edge
raw_edges = [t for t in edges['div_out_raw'] if t >= start_time]
ideal_edges = [t for t in edges['ideal_clk'] if t >= start_time]
dtc_edges = [t for t in edges['div_out_dtc'] if t >= start_time]

print(f"{'Fout#':>5} | {'raw_time':>10} | {'ideal_clk':>10} | {'raw-ideal':>9} | {'dtc_time':>10} | {'dtc-ideal':>9}")
print("-" * 70)

with open(csv_path, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['fout_n', 'raw_time_ps', 'ideal_clk_ps', 'raw_minus_ideal_ps', 'dtc_time_ps', 'dtc_minus_ideal_ps'])
    
    for n, raw_t in enumerate(raw_edges[:60]):
        # Find closest ideal_clk edge
        ideal_t = min(ideal_edges, key=lambda x: abs(x - raw_t))
        # Find closest dtc edge
        dtc_t = min(dtc_edges, key=lambda x: abs(x - raw_t))
        
        raw_err = raw_t - ideal_t
        dtc_err = dtc_t - ideal_t
        
        w.writerow([n, raw_t, ideal_t, raw_err, dtc_t, dtc_err])
        
        if n < 30:
            print(f"  {n:3d} | {raw_t:9d} | {ideal_t:9d} | {raw_err:8d} | {dtc_t:9d} | {dtc_err:8d}")

print(f"\nCSV saved: {csv_path}")
print(f"Total Fout edges in last 80us: {len(raw_edges)}")

# Summary stats
raw_errors = [t - min(ideal_edges, key=lambda x: abs(x - t)) for t in raw_edges[:60]]
dtc_errors = [t - min(ideal_edges, key=lambda x: abs(x - t)) for t in dtc_edges[:60]]
if raw_errors and dtc_errors:
    print(f"\nSummary (first 60 edges):")
    print(f"  div_out_raw: range [{min(raw_errors)}ps, {max(raw_errors)}ps]  std={int(np.std(raw_errors))}ps")
    print(f"  div_out_dtc: range [{min(dtc_errors)}ps, {max(dtc_errors)}ps]  std={int(np.std(dtc_errors))}ps")
