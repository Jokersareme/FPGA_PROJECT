# Find state transitions in the full VCD
import re

with open('tb_quick_3rd.vcd', 'rb') as f:
    data = f.read()

text = data.decode('latin-1')

# The body starts after first $dumpvars $end
idx = text.find('$dumpvars')
end_idx = text.find('$end', idx)
body = text[end_idx + 4:]

# State id is ." (two chars)
state_id = '."'
cal_start_id = 'X'  # From earlier analysis

# Search for state transitions - 4-bit binary followed by state_id
# Pattern: bXXXX followed by ."
state_matches = list(re.finditer(r'b([01]{4})\s+' + re.escape(state_id), body))
print(f"State transitions found: {len(state_matches)}")

# Get the times of these transitions
# Find which #time each match is in
for i, m in enumerate(state_matches[:20]):
    # Search backward from match position for the nearest #time
    pos = m.start()
    before = body[:pos]
    time_matches = list(re.finditer(r'#(\d+)', before))
    if time_matches:
        t = int(time_matches[-1].group(1))
        v = int(m.group(1), 2)
        sn = {0:'S_IDLE',1:'SM_MIN_CODE',2:'SM_MIN_DISCARD',3:'SM_MIN_FLUSH',
              4:'SM_MIN_MEAS',5:'SM_MIN_STORE',6:'SM_MAX_CODE',7:'SM_MAX_DISCARD',
              8:'SM_MAX_FLUSH',9:'SM_MAX_MEAS',10:'SM_MAX_STORE',11:'SM_DIVIDE',
              12:'SM_SATURATE',13:'SM_DONE',14:'SM_BG_WAIT'}.get(v,f'?{v}')
        print(f"  T={t:>10d}ps ({t/1000:>8.1f}ns): state = {sn}")

# Find cal_start_r transitions
cal_matches = list(re.finditer(r'([01])\s+' + re.escape(cal_start_id), body))
print(f"\ncal_start_r transitions: {len(cal_matches)}")
for i, m in enumerate(cal_matches[:10]):
    pos = m.start()
    before = body[:pos]
    time_matches = list(re.finditer(r'#(\d+)', before))
    if time_matches:
        t = int(time_matches[-1].group(1))
        print(f"  T={t:>10d}ps: cal_start_r = {m.group(1)}")

# Find cal_done transitions
cal_done_id = ','  # from earlier
cd_matches = list(re.finditer(r'([01])\s+' + re.escape(cal_done_id), body))
print(f"\ncal_done transitions: {len(cd_matches)}")
for i, m in enumerate(cd_matches[:5]):
    pos = m.start()
    before = body[:pos]
    time_matches = list(re.finditer(r'#(\d+)', before))
    if time_matches:
        t = int(time_matches[-1].group(1))
        print(f"  T={t:>10d}ps: cal_done = {m.group(1)}")

# Find cal_mode (calibrator) - id was '\'
cm_id = '\\'
cm_matches = list(re.finditer(r'([01])\s+' + re.escape(cm_id), body))
print(f"\ncal_mode (calibrator) transitions: {len(cm_matches)}")
for i, m in enumerate(cm_matches[:10]):
    pos = m.start()
    before = body[:pos]
    time_matches = list(re.finditer(r'#(\d+)', before))
    if time_matches:
        t = int(time_matches[-1].group(1))
        print(f"  T={t:>10d}ps: cal_mode = {m.group(1)}")
