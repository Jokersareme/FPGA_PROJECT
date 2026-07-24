"""Count edges using known VCD IDs from header"""
import re

with open(r'.\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

# Build set of all ID strings
ids_1char = set()
ids_2char = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+\s*\$end', txt[:txt.find('$dumpvars')]):
    idc = m.group(1)
    if len(idc) == 1:
        ids_1char.add(idc)
    elif len(idc) == 2:
        ids_2char.add(idc)

print(f'1-char IDs: {len(ids_1char)}, 2-char IDs: {len(ids_2char)}')
has_S = 'S' in ids_1char
has_Q = 'Q' in ids_1char
print(f'ID S (1-char): {has_S}, ID Q (1-char): {has_Q}')

# Check: are there any 2-char IDs starting with S or Q?
s_2char = [x for x in ids_2char if x.startswith('S')]
q_2char = [x for x in ids_2char if x.startswith('Q')]
print(f'2-char IDs starting with S: {s_2char}')
print(f'2-char IDs starting with Q: {q_2char}')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

time = 0
cur_dtc = 'x'
cur_raw = 'x'
dtc_count = 0
raw_count = 0

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
        # Try 2-char ID first
        if i + 1 < len(body):
            id2 = body[i:i+2]
            if id2 in ids_2char:
                i += 2
                if id2 == 'S':
                    if val == '1' and cur_dtc != '1':
                        dtc_count += 1
                    cur_dtc = val
                elif id2 == 'Q':
                    if val == '1' and cur_raw != '1':
                        raw_count += 1
                    cur_raw = val
                continue
        
        # Try 1-char ID
        if i < len(body) and body[i] in ids_1char:
            id1 = body[i]
            i += 1
            if id1 == 'S':
                if val == '1' and cur_dtc != '1':
                    dtc_count += 1
                cur_dtc = val
            elif id1 == 'Q':
                if val == '1' and cur_raw != '1':
                    raw_count += 1
                cur_raw = val
    else:
        i += 1

print(f'\nDTC (id=S) rising={dtc_count}')
print(f'Raw (id=Q) rising={raw_count}')
