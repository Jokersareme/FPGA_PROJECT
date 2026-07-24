"""Match dtc edges to nearest raw edges"""
import re, numpy as np

with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Build ID lookup
scope_stack = ['']
var_map = {}
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
    r'\$var (\w+) (\d+) (\S+) (\S+)', txt[:txt.find('$dumpvars')]):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        _, w, idc, nm = m.group(3), m.group(4), m.group(5), m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        var_map[idc] = (nm, full, int(w))

# Parse body
time = 0
cur_dtc = 'x'
cur_raw = 'x'
dtc_all = []
raw_all = []
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
        id_start = i
        if i < len(body) and body[i].isprintable() and body[i] not in ' \t\r\n#b0123456789':
            i += 1
            if i < len(body) and body[i].isprintable() and body[i] not in ' \t\r\n#b0123456789':
                id2 = body[id_start:id_start+2]
                id_str = id2 if id2 in var_map else body[id_start:id_start+1]
                if id2 in var_map:
                    i += 1
            else:
                id_str = body[id_start:id_start+1]
        else:
            id_str = ''
        
        if id_str == 'S':
            if val == '1' and cur_dtc != '1':
                dtc_all.append(time)
            cur_dtc = val
        elif id_str == 'Q':
            if val == '1' and cur_raw != '1':
                raw_all.append(time)
            cur_raw = val
    else:
        i += 1

# Only analyze after first sys_rst deassert (where simulation is stable)
# For each dtc edge, find the nearest raw edge (matching)
raw_arr = np.array(raw_all)
dtc_arr = np.array(dtc_all)

# Match: for each dtc edge, find the closest raw edge
matched = []
for dt in dtc_arr:
    # find closest raw edge
    nearest_raw = raw_arr[np.argmin(np.abs(raw_arr - dt))]
    delay = dt - nearest_raw
    matched.append((dt, nearest_raw, delay))

matched = np.array(matched)
dtc_m = matched[:, 0]
raw_m = matched[:, 1]
delay_m = matched[:, 2]

# Filter: only positive delays (dtc after raw) within reasonable range
valid = (delay_m > 0) & (delay_m < 100000)  # <100ns delay
valid_count = np.sum(valid)
print(f'Total dtc edges: {len(dtc_all)}, matched raw: {len(raw_all)}')
print(f'Valid (positive delay <100ns): {valid_count}')

# Filter for last 80us
max_t = max(dtc_all[-1], raw_all[-1])
start_t = max_t - 80000000
valid_late = valid & (dtc_m >= start_t)
late_delays = delay_m[valid_late]

if len(late_delays) > 0:
    print(f'\nValid delays (last 80us): {len(late_delays)}')
    print(f'  mean={np.mean(late_delays):.0f}ps')
    print(f'  std={np.std(late_delays):.0f}ps')
    print(f'  min={np.min(late_delays):.0f}ps  max={np.max(late_delays):.0f}ps')
    
    # Show sample
    print(f'\nFirst 15 valid delays:')
    cnt = 0
    for i in range(len(dtc_m)):
        if valid[i] and dtc_m[i] >= start_t:
            code_est = delay_m[i] / 80  # from code*80ps
            print(f'  raw={int(raw_m[i]):10d}  dtc={int(dtc_m[i]):10d}  delay={int(delay_m[i]):7d}ps  est_code={code_est:.1f}')
            cnt += 1
            if cnt >= 15:
                break

# Also compute raw period jitter and dtc compensated jitter
# Use only edges where dtc follows the same raw edge
print(f'\n=== Jitter comparison ===')
raw_per = np.diff(raw_all)
print(f'Raw period: mean={np.mean(raw_per):.0f}ps  std={np.std(raw_per):.0f}ps')
raw_c2c = np.diff(raw_per)
print(f'Raw c2c: std={np.std(raw_c2c):.0f}  max||={np.max(np.abs(raw_c2c)):.0f}')
