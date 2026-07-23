import re

with open('tb_top_auto_full.vcd', 'r') as f:
    content = f.read()

# Build full variable map
scope_stack = ['']
var_map = {}
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
                     r'\$var (\w+) (\d+) (\S+) (\S+)', content[:content.find('$dumpvars')]):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        _, w, idc, nm = m.group(3), m.group(4), m.group(5), m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        var_map[idc] = (nm, full, int(w))

# Find calibration signals
for idc, (nm, full, w) in var_map.items():
    if full.startswith('tb_top.u_dut.u_cal') and nm in ('state', 'next', 'dtc_gain_cal', 'tdc_min', 'tdc_max', 'cal_done', 'cal_mode'):
        print(f"  id={idc:4s} w={w:2d}  {full}")

# Search for state changes
state_id = next((idc for idc, (nm, full, w) in var_map.items() if full == 'tb_top.u_dut.u_cal.state'), None)
next_id = next((idc for idc, (nm, full, w) in var_map.items() if full == 'tb_top.u_dut.u_cal.next'), None)
gain_id_cal = next((idc for idc, (nm, full, w) in var_map.items() if full == 'tb_top.u_dut.u_cal.dtc_gain_cal'), None)
gain_id_top = next((idc for idc, (nm, full, w) in var_map.items() if full == 'tb_top.u_dut.dtc_gain_cal'), None)

print(f"\nstate_id  = {state_id}")
print(f"next_id   = {next_id}")
print(f"gain_cal  = {gain_id_cal}")
print(f"gain_top  = {gain_id_top}")

# Parse VCD body
body = content[content.find('$end', content.find('$dumpvars')) + 4:]
entries = re.findall(r'#(\d+)\s+(.*?)(?=#|\Z)', body)

state_names = {0:'S_IDLE', 1:'SM_MIN_CODE', 2:'SM_MIN_DISCARD', 3:'SM_MIN_FLUSH',
    4:'SM_MIN_MEAS', 5:'SM_MIN_STORE', 6:'SM_MAX_CODE', 7:'SM_MAX_DISCARD',
    8:'SM_MAX_FLUSH', 9:'SM_MAX_MEAS', 10:'SM_MAX_STORE', 11:'SM_DIVIDE',
    12:'SM_SATURATE', 13:'SM_DONE'}

print("\n=== Calibrator State Machine (first 600ns) ===")
prev_s, prev_n = -1, -1
gain_vals_cal = []

for t_str, vals in entries:
    t = int(t_str)
    if t > 600000:
        if gain_id_cal:
            m = re.search(r'b([01]{10})\s*' + re.escape(gain_id_cal), vals)
            if m:
                g = int(m.group(1), 2)
                if len(gain_vals_cal) == 0 or gain_vals_cal[-1][1] != g:
                    gain_vals_cal.append((t, g))
        continue
    
    if state_id:
        m = re.search(r'b([01]+)\s*' + re.escape(state_id), vals)
        if m:
            sv = int(m.group(1), 2)
            if sv != prev_s:
                sn = state_names.get(sv, f'?({sv})')
                print(f"  T={t:6d}ps ({t/1000:5.1f}ns): state = {sn}")
                prev_s = sv
    
    if next_id:
        m = re.search(r'b([01]+)\s*' + re.escape(next_id), vals)
        if m:
            nv = int(m.group(1), 2)
            if nv != prev_n:
                nn = state_names.get(nv, f'?({nv})')
                print(f"  T={t:6d}ps ({t/1000:5.1f}ns):  next = {nn}")
                prev_n = nv

if gain_vals_cal:
    print(f"\n=== dtc_gain_cal (post-calibration) ===")
    for t, g in gain_vals_cal:
        print(f"  T={t/1000:.1f}ns: gain = {g}")

# Final gain value
if gain_id_cal:
    print(f"\n=== Final dtc_gain_cal lookup ===")
    for t_str, vals in reversed(entries):
        t = int(t_str)
        m = re.search(r'b([01]{10})\s*' + re.escape(gain_id_cal), vals)
        if m:
            print(f"  Last at T={t/1000:.1f}ns: dtc_gain_cal = {int(m.group(1), 2)}")
            break

if gain_id_top:
    print(f"\n=== Final top-level dtc_gain_cal lookup ===")
    for t_str, vals in reversed(entries):
        t = int(t_str)
        m = re.search(r'b([01]{10})\s*' + re.escape(gain_id_top), vals)
        if m:
            print(f"  Last at T={t/1000:.1f}ns: dtc_gain_cal = {int(m.group(1), 2)}")
            break
