"""Check actual eo_dly_sel value in VCD"""
import re

with open('tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

all_ids = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+', txt[:txt.find('$dumpvars')]):
    all_ids.add(m.group(1))

# eo_dly_sel id='C"' (2-bit), dump all unique values
eo_dly_vals = set()
time = 0
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
            nxt = body[i]
            if nxt.isprintable() and nxt not in ' \t\r\n#b':
                id_str = body[i:i+2] if (i+1 < len(body) and body[i:i+2] in all_ids) else nxt
                i += 2 if id_str == body[i:i+2] else 1
                if id_str == 'C"':
                    eo_dly_vals.add(val)
                    if len(eo_dly_vals) <= 8:
                        print(f'  t={time:>12d}  eo_dly_sel = {val}')
    elif c == 'b':
        i += 1
        bits = ''
        while i < len(body) and body[i] in '01xzXZ':
            bits += body[i]; i += 1
        while i < len(body) and body[i] in ' \t\r\n':
            i += 1
        if i < len(body):
            nxt = body[i]
            if nxt.isprintable() and nxt not in ' \t\r\n#b':
                id_str = body[i:i+2] if (i+1 < len(body) and body[i:i+2] in all_ids) else nxt
                i += 2 if id_str == body[i:i+2] else 1
                if id_str == 'C"':
                    eo_dly_vals.add(bits)
                    if len(eo_dly_vals) <= 8:
                        print(f'  t={time:>12d}  eo_dly_sel = b{bits}')

print(f'\nAll unique eo_dly_sel values: {sorted(eo_dly_vals)}')
