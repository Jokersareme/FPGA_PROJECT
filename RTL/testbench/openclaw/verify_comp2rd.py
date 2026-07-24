"""Verify: comp_2rd = signed(e_o_1) + y_o_2*1024 + y_o_3*1024
   All signals from the SAME clock cycle (use raw e_o_1, not delayed Eo_raw)"""
import re, csv

vcd_path = r'tb_quick_3rd.vcd'
csv_path = r'comp_2rd_verify.csv'

with open(vcd_path, 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]

all_ids = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+', header):
    all_ids.add(m.group(1))

# Same-cycle signals (all registered at posedge clk_delta_sigma = Fout)
# e_o_1 = u_hk_efm_1.e_o = id='E$' (10-bit)
# y_o_2 = u_hk_efm_2.y_o = id='1$' (1-bit)
# y_o_3 = u_hk_efm_3.y_o = id='0$' (1-bit)
targets = {
    'E$': 'e_o_1',
    '1$': 'y_o_2',
    '0$': 'y_o_3',
}

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

def to_signed(bits, w):
    if not bits or bits[0] not in '01': return None
    v = int(bits, 2)
    if v >= (1 << (w-1)): v -= (1 << w)
    return v

max_t = 242103000
start_t = max_t - 100000000

cur = {nm: '0' for nm in targets.values()}
prev_raw = 'x'
rows = []

i = 0
time = 0
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
                nm = targets.get(id_str)
                if nm in ('y_o_2', 'y_o_3'):
                    cur[nm] = val
                # div_out_raw rising edge
                if id_str == 'Q' and val == '1' and prev_raw != '1' and time >= start_t:
                    e1 = to_signed(cur['e_o_1'], 10)
                    y2 = int(cur['y_o_2'])
                    y3 = int(cur['y_o_3'])
                    if e1 is not None:
                        calc = e1 + y2 * 1024 + y3 * 1024
                        rows.append((time, e1, y2, y3, calc))
                if id_str == 'Q':
                    prev_raw = val
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
                nm = targets.get(id_str)
                if nm:
                    cur[nm] = bits
    else:
        i += 1

print(f'Total cycles (same-cycle e_o_1 + y_o_2*1024 + y_o_3*1024): {len(rows)}')
print()
for i, (t, e1, y2, y3, calc) in enumerate(rows[:10]):
    print(f'  t={t}  e_o_1={e1:5d}  y2={y2}  y3={y3}  calc={calc:6d}')
print(f'  ...')
for t, e1, y2, y3, calc in rows[-3:]:
    print(f'  t={t}  e_o_1={e1:5d}  y2={y2}  y3={y3}  calc={calc:6d}')

# Stats
vals = [r[4] for r in rows]
print(f'\n  Range: {min(vals)} ~ {max(vals)}')
print(f'  Mean: {sum(vals)/len(vals):.1f}')

with open(csv_path, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['time_ps', 'e_o_1', 'y_o_2', 'y_o_3', 'comp2rd_same_cycle'])
    for t, e1, y2, y3, calc in rows:
        w.writerow([t, e1, y2, y3, calc])
print(f'\nCSV: {csv_path}')
