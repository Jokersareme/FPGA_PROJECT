"""VCD edge parser - correctly handles 1-char and 2-char IDs"""
import re, numpy as np

with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Build ID lookup: scan header for all IDs and their widths
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

# Find dtc (S) and raw (Q) - confirm 1-char IDs
for idc, (nm, full, w) in var_map.items():
    if idc in ('S', 'Q'):
        print(f'  id={idc!r} w={w}  {nm} = {full}')

# Scan body for scalar entries: value(0/1/x/z) followed by ID of known length
time = 0
cur_dtc = 'x'
cur_raw = 'x'
dtc_edges = []
raw_edges = []
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
        # ID starts here
        id_start = i
        # Try 2-char ID first, then 1-char
        # An ID is printable chars that are NOT digits, #, b, or whitespace
        if i < len(body) and body[i].isprintable() and body[i] not in ' \t\r\n#b0123456789':
            i += 1
            # Check if second char exists and is valid ID char
            if i < len(body) and body[i].isprintable() and body[i] not in ' \t\r\n#b0123456789':
                # Try 2-char ID
                id2 = body[id_start:id_start+2]
                if id2 in var_map:
                    id_str = id2
                    i += 1
                else:
                    id_str = body[id_start:id_start+1]  # 1-char
            else:
                id_str = body[id_start:id_start+1]  # 1-char
        else:
            id_str = ''
        
        if id_str == 'S':
            if val == '1' and cur_dtc != '1':
                dtc_edges.append(time)
            cur_dtc = val
        elif id_str == 'Q':
            if val == '1' and cur_raw != '1':
                raw_edges.append(time)
            cur_raw = val
    else:
        i += 1

max_t = max(raw_edges[-1], dtc_edges[-1]) if raw_edges and dtc_edges else 0
start_t = max_t - 80000000
raw_e = [t for t in raw_edges if t >= start_t]
dtc_e = [t for t in dtc_edges if t >= start_t]

n = min(len(raw_e), len(dtc_e))
raw_e = raw_e[:n]
dtc_e = dtc_e[:n]

print(f'\nLast 80us: raw={len(raw_e)} dtc={len(dtc_e)} edges')

if len(raw_e) > 1 and len(dtc_e) > 1:
    raw_per = np.diff(raw_e)
    dtc_per = np.diff(dtc_e)
    print(f'Raw period: mean={np.mean(raw_per):.0f}ps  std={np.std(raw_per):.0f}ps')
    print(f'DTC period: mean={np.mean(dtc_per):.0f}ps  std={np.std(dtc_per):.0f}ps')

    raw_c2c = np.diff(raw_per)
    dtc_c2c = np.diff(dtc_per)
    print(f'Raw c2c: std={np.std(raw_c2c):.0f}  max||={np.max(np.abs(raw_c2c)):.0f}')
    print(f'DTC c2c: std={np.std(dtc_c2c):.0f}  max||={np.max(np.abs(dtc_c2c)):.0f}')
    print(f'DTC jitter improvement: {100*(1-np.std(dtc_c2c)/np.std(raw_c2c)):.0f}%')

print(f'\nFirst 10 delays:')
for i in range(min(10, len(raw_e))):
    delay = dtc_e[i] - raw_e[i]
    print(f'  raw={raw_e[i]:10d}  dtc={dtc_e[i]:10d}  delay={delay:7d}ps')
