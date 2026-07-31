# Find when calibrator transitions happen
import re

with open('tb_quick_3rd.vcd', 'r') as f:
    c = f.read()

header = c[:c.find('$dumpvars')]
body = c[c.find('$end', c.find('$dumpvars')) + 4:]

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

entries = [(int(t), vals) for t, vals in re.findall(r'#(\d+)\s+(.*?)(?=#|\Z)', body)]

state_names = {0:'S_IDLE', 1:'SM_MIN_CODE', 2:'SM_MIN_DISCARD', 3:'SM_MIN_FLUSH',
    4:'SM_MIN_MEAS', 5:'SM_MIN_STORE', 6:'SM_MAX_CODE', 7:'SM_MAX_DISCARD',
    8:'SM_MAX_FLUSH', 9:'SM_MAX_MEAS', 10:'SM_MAX_STORE', 11:'SM_DIVIDE',
    12:'SM_SATURATE', 13:'SM_DONE', 14:'SM_BG_WAIT'}

# Find state signal
state_ids = [(idc, full) for idc, (nm, full, w) in var_map.items() if full.endswith('.state') and 'u_cal' in full]
if state_ids:
    state_id = state_ids[0][0]
    print(f"State ID: {state_id!r}")
    
    print(f"\n=== All state transitions ===")
    prev = None
    for t, vals in entries[:5000]:
        m = re.search(r'b([01]+)\s*' + re.escape(state_id), vals)
        if m:
            v = int(m.group(1), 2)
            if v != prev:
                sn = state_names.get(v, f'?({v})')
                print(f"  T={t:>10d}ps ({t/1000:>8.1f}ns): state = {sn}")
                prev = v

# Find cal_mode from calibrator
cm_ids = [(idc, full) for idc, (nm, full, w) in var_map.items() if full.endswith('u_cal.cal_mode')]
if cm_ids:
    cm_id = cm_ids[0][0]
    print(f"\n=== cal_mode (calibrator) transitions ===")
    prev = None
    for t, vals in entries[:500]:
        m = re.search(r'([01])\s*' + re.escape(cm_id), vals)
        if m:
            v = int(m.group(1))
            if v != prev:
                print(f"  T={t:>10d}ps ({t/1000:>6.1f}ns): cal_mode = {v}")
                prev = v

# Find cal_mode from lut_dtc_top
cm2_ids = [(idc, full) for idc, (nm, full, w) in var_map.items() if full.endswith('u_lut_dtc_top.cal_mode')]
if cm2_ids:
    cm2_id = cm2_ids[0][0]
    print(f"\n=== cal_mode (lut_dtc_top) transitions ===")
    prev = None
    for t, vals in entries[:500]:
        m = re.search(r'([01])\s*' + re.escape(cm2_id), vals)
        if m:
            v = int(m.group(1))
            if v != prev:
                print(f"  T={t:>10d}ps ({t/1000:>6.1f}ns): cal_mode = {v}")
                prev = v

# Find clk_out_pll (vco_clk) transitions
vco_ids = [(idc, full) for idc, (nm, full, w) in var_map.items() if full.endswith('.clk_out_pll')]
if vco_ids:
    vco_id = vco_ids[0][0]
    print(f"\n=== clk_out_pll (vco_clk) first 10 transitions ===")
    cnt = 0
    for t, vals in entries:
        m = re.search(r'([01])\s*' + re.escape(vco_id), vals)
        if m:
            print(f"  T={t:>10d}ps: vco_clk = {m.group(1)}")
            cnt += 1
            if cnt >= 10: break

# Find sys_clk_g transitions
clk_ids = [(idc, full) for idc, (nm, full, w) in var_map.items() if full.endswith('.sys_clk_g')]
if clk_ids:
    clk_id = clk_ids[0][0]
    print(f"\n=== sys_clk_g first 10 transitions ===")
    cnt = 0
    for t, vals in entries:
        m = re.search(r'([01])\s*' + re.escape(clk_id), vals)
        if m:
            print(f"  T={t:>10d}ps: sys_clk = {m.group(1)}")
            cnt += 1
            if cnt >= 10: break
