"""Final check: does DTC delay change with code?"""
import re

with open(r'.\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

# Build ID sets
ids_1char = set()
ids_2char = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+\s*\$end', txt[:txt.find('$dumpvars')]):
    idc = m.group(1)
    if len(idc) == 1: ids_1char.add(idc)
    elif len(idc) == 2: ids_2char.add(idc)

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

time = 0
cur_dtc = 'x'
cur_raw = 'x'
dtc_times = []
raw_times = []

i = 0
while i < len(body):
    c = body[i]
    if c == '#':
        j = i + 1
        while j < len(body) and body[j].isdigit():
            j += 1
        if j > i + 1: time = int(body[i+1:j])
        i = j
    elif c in '01xz':
        val = c
        i += 1
        if i + 1 < len(body):
            id2 = body[i:i+2]
            if id2 in ids_2char:
                i += 2
                if id2 == 'S' and val == '1' and cur_dtc != '1':
                    dtc_times.append(time); cur_dtc = '1'
                elif id2 == 'Q' and val == '1' and cur_raw != '1':
                    raw_times.append(time); cur_raw = '1'
                continue
        if i < len(body) and body[i] in ids_1char:
            id1 = body[i]; i += 1
            if id1 == 'S' and val == '1' and cur_dtc != '1':
                dtc_times.append(time); cur_dtc = '1'
            elif id1 == 'Q' and val == '1' and cur_raw != '1':
                raw_times.append(time); cur_raw = '1'
        if val != '1':
            if 'S' == id1 if 'id1' in dir() else None:
                cur_dtc = val
            elif 'Q' == id1 if 'id1' in dir() else None:
                cur_raw = val
    else:
        i += 1

# Match edges and compute delays
print(f'Raw edges: {len(raw_times)}, DTC edges: {len(dtc_times)}')
print(f'\nFirst 20 delays:')
for i in range(min(20, len(raw_times), len(dtc_times))):
    delay = dtc_times[i] - raw_times[i]
    code_est = delay / 80  # 80ps per code (4 stages * 20ps)
    print(f'  raw={raw_times[i]:10d}ps  dtc={dtc_times[i]:10d}ps  delay={delay:6d}ps  est_code={code_est:6.1f}')
