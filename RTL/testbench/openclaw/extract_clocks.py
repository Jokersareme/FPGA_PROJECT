"""Extract all rising edges in last 100us"""
import re, csv

vcd_path = r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd'
csv_path = r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\clock_edges.csv'

with open(vcd_path, 'rb') as f:
    txt = f.read().decode('latin-1')

# Build ID sets
ids_1char = set()
ids_2char = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+\s*\$end', txt[:txt.find('$dumpvars')]):
    idc = m.group(1)
    if len(idc) == 1: ids_1char.add(idc)
    elif len(idc) == 2: ids_2char.add(idc)

target_sig = {}
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+(\S+)\s*\$end', txt[:txt.find('$dumpvars')]):
    idc, nm = m.group(1), m.group(2)
    if nm in ('ideal_clk', 'div_out_raw', 'div_out_dtc'):
        target_sig[idc] = nm

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

time = 0
all_edges = {'ideal_clk': [], 'div_out_raw': [], 'div_out_dtc': []}
prev = {'ideal_clk': 'x', 'div_out_raw': 'x', 'div_out_dtc': 'x'}

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
        if i + 1 < len(body) and body[i:i+2] in ids_2char:
            id2 = body[i:i+2]; i += 2
            if id2 in target_sig:
                nm = target_sig[id2]
                if val == '1' and prev[nm] != '1':
                    all_edges[nm].append(time)
                prev[nm] = val
        elif i < len(body) and body[i] in ids_1char:
            id1 = body[i]; i += 1
            if id1 in target_sig:
                nm = target_sig[id1]
                if val == '1' and prev[nm] != '1':
                    all_edges[nm].append(time)
                prev[nm] = val
    else:
        i += 1

# Find last 100us
max_time = max(max(v) for v in all_edges.values() if v)
start_time = max_time - 100000000  # 100us in ps

print(f'Max time: {max_time/1e6:.1f}us, Start: {start_time/1e6:.1f}us')
print()

for nm in ('ideal_clk', 'div_out_raw', 'div_out_dtc'):
    edges_in_range = [t for t in all_edges[nm] if t >= start_time]
    print(f'{nm}: {len(edges_in_range)} edges in last 100us')

# Filter to last 100us
raw_e = [t for t in all_edges['div_out_raw'] if t >= start_time]
ideal_e = [t for t in all_edges['ideal_clk'] if t >= start_time]
dtc_e = [t for t in all_edges['div_out_dtc'] if t >= start_time]

print(f'\nExporting {len(raw_e)} raw edges from last 100us')

with open(csv_path, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['n', 'ideal_time_ps', 'raw_time_ps', 'dtc_time_ps',
                'ideal_raw_diff_ps', 'ideal_dtc_diff_ps',
                'raw_period_ps', 'dtc_period_ps'])
    
    for n, raw_t in enumerate(raw_e):
        ideal_t = min(ideal_e, key=lambda x: abs(x - raw_t))
        dtc_t = min(dtc_e, key=lambda x: abs(x - raw_t))
        i2r = raw_t - ideal_t
        i2d = dtc_t - ideal_t
        rp = raw_t - raw_e[n-1] if n > 0 else 0
        dp = dtc_t - prev_dtc if n > 0 else 0
        w.writerow([n, ideal_t, raw_t, dtc_t, i2r, i2d, rp, dp])
        prev_dtc = dtc_t

print(f'CSV: {csv_path}')
print(f'\nFirst 5 rows:')
with open(csv_path, 'r') as f:
    for i, line in enumerate(f):
        if i >= 6: break
        print(f'  {line.strip()}')
print(f'\nLast 5 rows:')
with open(csv_path, 'rb') as f:
    lines = f.read().decode().strip().split('\n')
    for line in lines[-5:]:
        print(f'  {line}')
