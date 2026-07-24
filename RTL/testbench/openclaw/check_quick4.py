# Check calibrator internal signals in VCD
import re

with open('tb_quick_3rd.vcd', 'r') as f:
    c = f.read()

# Find all variable declarations
header = c[:c.find('$dumpvars')]
vars_info = {}
for m in re.finditer(r'\$var (\w+) (\d+) (\S+) (\S+) \$end', header):
    t, w, idc, nm = m.group(1), m.group(2), m.group(3), m.group(4)
    vars_info[idc] = (t, int(w), nm)

print("=== All VCD Variables ===")
for idc, (t, w, nm) in sorted(vars_info.items(), key=lambda x: x[0]):
    print(f"  id={idc!r:4s} type={t:3s} w={w:2d}  {nm}")

# Find cal_mode transitions
body = c[c.find('$end', c.find('$dumpvars')) + 4:]
entries = re.findall(r'#(\d+)\s+(.*?)(?=#|\Z)', body)

# Map variable names to their IDs
name_to_id = {}
for idc, (t, w, nm) in vars_info.items():
    name_to_id[nm] = idc

# Check cal_mode
if 'cal_mode' in name_to_id:
    cm_id = name_to_id['cal_mode']
    print(f"\n=== cal_mode (id={cm_id!r}) transitions ===")
    prev = -1
    for t_str, vals in entries[:500]:
        t = int(t_str)
        if t > 5000: break
        m = re.search(r'([01])\s*' + re.escape(cm_id), vals)
        if m:
            v = int(m.group(1))
            if v != prev:
                print(f"  T={t:6d}ps: cal_mode = {v}")
                prev = v

# Check div_busy
if 'div_busy' in name_to_id:
    db_id = name_to_id['div_busy']
    print(f"\n=== div_busy (id={db_id!r}) transitions ===")
    prev = -1
    for t_str, vals in entries:
        t = int(t_str)
        if t > 50000: break
        m = re.search(r'([01])\s*' + re.escape(db_id), vals)
        if m:
            v = int(m.group(1))
            if v != prev:
                print(f"  T={t:8d}ps: div_busy = {v}")
                prev = v

# Check cal_done
if 'cal_done' in name_to_id:
    cd_id = name_to_id['cal_done']
    print(f"\n=== cal_done (id={cd_id!r}) transitions ===")
    prev = -1
    for t_str, vals in entries:
        t = int(t_str)
        if t > 50000: break
        m = re.search(r'([01])\s*' + re.escape(cd_id), vals)
        if m:
            v = int(m.group(1))
            if v != prev:
                print(f"  T={t:8d}ps: cal_done = {v}")
                prev = v

# Check cal_start_r
if 'cal_start_r' in name_to_id:
    cs_id = name_to_id['cal_start_r']
    print(f"\n=== cal_start_r (id={cs_id!r}) transitions ===")
    prev = -1
    for t_str, vals in entries[:200]:
        t = int(t_str)
        if t > 5000: break
        m = re.search(r'([01])\s*' + re.escape(cs_id), vals)
        if m:
            v = int(m.group(1))
            if v != prev:
                print(f"  T={t:6d}ps: cal_start_r = {v}")
                prev = v

# Check cal_mode_sel
if 'cal_mode_sel' in name_to_id:
    cms_id = name_to_id['cal_mode_sel']
    print(f"\n=== cal_mode_sel (id={cms_id!r}) transitions ===")
    prev = -1
    for t_str, vals in entries[:500]:
        t = int(t_str)
        if t > 5000: break
        m = re.search(r'([01])\s*' + re.escape(cms_id), vals)
        if m:
            v = int(m.group(1))
            if v != prev:
                print(f"  T={t:6d}ps: cal_mode_sel = {v}")
                prev = v

# Check dtc_gain_cal
if 'dtc_gain_cal' in name_to_id:
    dg_id = name_to_id['dtc_gain_cal']
    print(f"\n=== dtc_gain_cal (id={dg_id!r}) transitions ===")
    prev = -1
    for t_str, vals in entries:
        t = int(t_str)
        if t > 50000: break
        m = re.search(r'b([01]{10})\s*' + re.escape(dg_id), vals)
        if m:
            v = int(m.group(1), 2)
            if v != prev:
                print(f"  T={t:8d}ps: dtc_gain_cal = {v}")
                prev = v
