# Analyze calibrator stall
import re

with open('tb_quick_3rd.vcd', 'r') as f:
    c = f.read()

header = c[:c.find('$dumpvars')]
body = c[c.find('$end', c.find('$dumpvars')) + 4:]

# Build scope-qualified variable map
scope_stack = ['']
var_map = {}
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
                     r'\$var (\w+) (\d+) (\S+) (\S+)', header):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        _, w, idc, nm = m.group(3), m.group(4), m.group(5), m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        var_map[idc] = (nm, full, int(w))

# Print all calibrator + TDC related signals
print("=== Calibrator & TDC Signals ===")
for idc, (nm, full, w) in sorted(var_map.items(), key=lambda x: (x[1][1], x[1][0])):
    if any(k in full.lower() for k in ['u_cal','tdc','cal_mode','cal_result','cal_valid','latch','div_out_raw']):
        print(f"  id={idc!r:4s} w={w:2d}  {full}")

# Find specific signals
def find_id(name_part):
    return [idc for idc, (nm, full, w) in var_map.items() if name_part.lower() in full.lower()]

entries = [(int(t), vals) for t, vals in re.findall(r'#(\d+)\s+(.*?)(?=#|\Z)', body)]

# Check cal_mode (from calibrator)
for sig_name in ['cal_mode', 'state', 'cal_done', 'tdc_valid', 'tdc_count', 'cal_mode_m2', 'din_rise', 'din_delayed']:
    ids = find_id(sig_name)
    if ids:
        idc = ids[0]
        nm, full, w = var_map[idc]
        print(f"\n=== {full} (id={idc!r}) transitions (first 20000ps) ===")
        prev = None
        for t, vals in entries:
            if t > 20000: break
            if w == 1:
                m = re.search(r'([01xz])\s*' + re.escape(idc), vals, re.IGNORECASE)
            else:
                m = re.search(r'b([01xz]+)\s*' + re.escape(idc), vals, re.IGNORECASE)
            if m:
                v = m.group(1) if w == 1 else m.group(1)
                if v != prev:
                    print(f"  T={t:8d}ps: {v}")
                    prev = v
    else:
        print(f"\n=== {sig_name} NOT FOUND in VCD ===")
