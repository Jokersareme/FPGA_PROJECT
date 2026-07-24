# Compare raw vs dtc jitter with correct ID parsing
import re, numpy as np

with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Parse edges correctly - single-char IDs only
time = 0
raw_edges = []
dtc_edges = []
prev_raw = 'x'
prev_dtc = 'x'

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
    elif c in '01':
        val = c
        i += 1
        j = i
        # Read exact 1 char for single-char ID
        # Check: is the next char printable and part of ID?
        if j < len(body):
            nxt = body[j]
            # Single-char ID: next char is whitespace, #, or non-printable
            # Multi-char ID: next char is printable and not # or whitespace
            if nxt in ' \t\r\n#0123456789':
                # single-char ID: just this one char
                id_str = body[i:i+1]
                i += 1
            else:
                # multi-char ID: read until delimiter
                while j < len(body) and body[j].isprintable() and body[j] not in ' \t\r\n#b':
                    j += 1
                id_str = body[i:j]
                i = j
            
            if id_str == 'Q':
                if val == '1' and prev_raw != '1':
                    raw_edges.append(time)
                prev_raw = val
            elif id_str == 'S':
                if val == '1' and prev_dtc != '1':
                    dtc_edges.append(time)
                prev_dtc = val
    else:
        i += 1

max_t = max(raw_edges[-1], dtc_edges[-1])
start_t = max_t - 80000000

# Only last 80us (where DTC is active after reset)
raw_e = [t for t in raw_edges if t >= start_t]
dtc_e = [t for t in dtc_edges if t >= start_t]

# Align: take min length
n = min(len(raw_e), len(dtc_e))
raw_e = raw_e[:n]
dtc_e = dtc_e[:n]

print(f'Ray edges: {len(raw_e)}, DTC edges: {len(dtc_e)} (last 80us)')

raw_per = np.diff(raw_e)
dtc_per = np.diff(dtc_e)

# Period jitter (absolute)
import os
csv_path = r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\jitter_compare.csv'
with open(csv_path, 'w', newline='') as f:
    import csv
    w = csv.writer(f)
    w.writerow(['edge', 'raw_time', 'dtc_time', 'raw_period', 'dtc_period'])
    for i in range(len(raw_e)):
        rp = raw_per[i] if i < len(raw_per) else 0
        dp = dtc_per[i] if i < len(dtc_per) else 0
        w.writerow([i, raw_e[i], dtc_e[i], rp, dp])

print(f'CSV: {csv_path}')
print(f'Raw period: mean={np.mean(raw_per):.0f}ps  std={np.std(raw_per):.0f}ps')
print(f'DTC period: mean={np.mean(dtc_per):.0f}ps  std={np.std(dtc_per):.0f}ps')

raw_c2c = np.diff(raw_per)
dtc_c2c = np.diff(dtc_per)
print(f'')
print(f'Raw c2c jitter:  std={np.std(raw_c2c):.0f}ps  max||={np.max(np.abs(raw_c2c)):.0f}ps')
print(f'DTC c2c jitter:  std={np.std(dtc_c2c):.0f}ps  max||={np.max(np.abs(dtc_c2c)):.0f}ps')
print(f'DTC improvement (std): {100*(1-np.std(dtc_c2c)/np.std(raw_c2c)):.0f}%')

# Show first 20 periods
print(f'\n=== First 20 periods ===')
print(f'{"n":>4} | {"raw_per":>10} | {"dtc_per":>10} | {"diff":>10}')
for i in range(min(20, len(raw_per))):
    diff = dtc_per[i] - raw_per[i]
    print(f'{i:4d} | {raw_per[i]:10.0f} | {dtc_per[i]:10.0f} | {diff:10.0f}')
