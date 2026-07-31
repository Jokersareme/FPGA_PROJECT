import re

with open("tb_quick_3rd.vcd", "r") as f:
    content = f.read()

# Find variable IDs
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

# Find calibrator signals
state_id = next((idc for idc, (nm, full, w) in var_map.items() if full.endswith('u_cal.state')), None)
next_id = next((idc for idc, (nm, full, w) in var_map.items() if full.endswith('u_cal.next')), None)
gain_id = next((idc for idc, (nm, full, w) in var_map.items() if full.endswith('dtc_gain_cal')), None)
cal_done_id = next((idc for idc, (nm, full, w) in var_map.items() if full.endswith('.cal_done') and 'u_dut' in full), None)
cal_start_id = next((idc for idc, (nm, full, w) in var_map.items() if full.endswith('cal_start_r')), None)
wait_cnt_id = next((idc for idc, (nm, full, w) in var_map.items() if full.endswith('u_cal.wait_cnt')), None)
div_busy_id = next((idc for idc, (nm, full, w) in var_map.items() if full.endswith('u_cal.div_busy')), None)
cal_valid_id = next((idc for idc, (nm, full, w) in var_map.items() if full.endswith('u_lut_dtc_top.cal_valid')), None)

print("=== Variable IDs ===")
print(f"state     = {state_id}")
print(f"next      = {next_id}")
print(f"gain_cal  = {gain_id}")
print(f"cal_done  = {cal_done_id}")
print(f"cal_start = {cal_start_id}")
print(f"wait_cnt  = {wait_cnt_id}")
print(f"div_busy  = {div_busy_id}")
print(f"cal_valid = {cal_valid_id}")

state_names = {0:'S_IDLE', 1:'SM_MIN_CODE', 2:'SM_MIN_DISCARD', 3:'SM_MIN_FLUSH',
    4:'SM_MIN_MEAS', 5:'SM_MIN_STORE', 6:'SM_MAX_CODE', 7:'SM_MAX_DISCARD',
    8:'SM_MAX_FLUSH', 9:'SM_MAX_MEAS', 10:'SM_MAX_STORE', 11:'SM_DIVIDE',
    12:'SM_SATURATE', 13:'SM_DONE', 14:'SM_BG_WAIT'}

body = content[content.find('$end', content.find('$dumpvars')) + 4:]
entries = re.findall(r'#(\d+)\s+(.*?)(?=#|\Z)', body)

print("\n=== Calibrator States (first 5000ps) ===")
prev_s = -1
for t_str, vals in entries:
    t = int(t_str)
    if t > 5000: break
    if state_id:
        m = re.search(r'b([01]+)\s*' + re.escape(state_id), vals)
        if m:
            sv = int(m.group(1), 2)
            if sv != prev_s:
                sn = state_names.get(sv, f'?({sv})')
                print(f"  T={t:6d}ps: state = {sn}")
                prev_s = sv

print("\n=== Full State Timeline (key transitions) ===")
prev_s, prev_g = -1, -1
for t_str, vals in entries:
    t = int(t_str)
    if t > 20000: break
    if state_id:
        m = re.search(r'b([01]+)\s*' + re.escape(state_id), vals)
        if m:
            sv = int(m.group(1), 2)
            if sv != prev_s:
                sn = state_names.get(sv, f'?({sv})')
                print(f"  T={t:6d}ps: state = {sn}")
                prev_s = sv
    if gain_id:
        m = re.search(r'b([01]{10})\s*' + re.escape(gain_id), vals)
        if m:
            gv = int(m.group(1), 2)
            if gv != prev_g:
                print(f"  T={t:6d}ps: dtc_gain_cal = {gv}")
                prev_g = gv

if cal_done_id:
    print(f"\ncal_done transitions:")
    prev_d = -1
    for t_str, vals in entries:
        t = int(t_str)
        if t > 30000: break
        m = re.search(r'([01])\s*' + re.escape(cal_done_id), vals)
        if m:
            dv = int(m.group(1))
            if dv != prev_d:
                print(f"  T={t:6d}ps: cal_done = {dv}")
                prev_d = dv
