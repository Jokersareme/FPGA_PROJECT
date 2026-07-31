"""Check DTC delay: compare raw vs dtc_g edges"""
import re, numpy as np

with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

# Build ID map
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

# Print IDs for raw and dtc
for idc, (nm, full, w) in var_map.items():
    if any(x in full for x in ['div_out_dtc', 'div_out_raw']):
        print(f'  id={idc!r:6s} w={w}  {full}')

# Use div_out_dtc_g (id='R') and raw = div_out_raw (id='Q')
raw_id = 'Q'
dtc_id = 'R'  # div_out_dtc_g
print(f'\nUsing: raw={raw_id!r}  dtc_g={dtc_id!r}')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Parse - character by character with proper 2-char ID handling
time = 0
raw_vals = []
dtc_vals = []

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
            # First char of ID
            c1 = body[i]
            if c1.isprintable() and c1 not in ' \t\r\n#b0123456789':
                i += 1
                # Second char?
                if i < len(body):
                    c2 = body[i]
                    if c2.isprintable() and c2 not in ' \t\r\n#b0123456789':
                        id_str = c1 + c2
                        i += 1
                    else:
                        id_str = c1
                else:
                    id_str = c1
            else:
                id_str = ''
            
            if id_str == raw_id:
                raw_vals.append((time, val))
            elif id_str == dtc_id:
                dtc_vals.append((time, val))
    else:
        i += 1

# Extract rising edges
raw_rise = [t for t, v in raw_vals if v == '1']
dtc_rise = [t for t, v in dtc_vals if v == '1']

print(f'\nRaw rising: {len(raw_rise)}, DTC_g rising: {len(dtc_rise)}')

# Match each dtc_g edge to closest raw edge
for i, dt in enumerate(dtc_rise[:20]):
    best_raw = min(raw_rise, key=lambda r: abs(r - dt))
    delay = dt - best_raw
    print(f'  dtc_g[{i}]={dt:10d}  closest_raw={best_raw:10d}  delay={delay:6d}ps')
