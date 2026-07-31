"""Export clocks + comp_2rd_tb at div_out_raw rising edges"""
import re, csv

vcd_path = r'tb_quick_3rd.vcd'
csv_path = r'mash_export_v5.csv'

with open(vcd_path, 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]

all_ids = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+', header):
    all_ids.add(m.group(1))

# IDs from new VCD (testbench-added signals shifted everything)
target_ids = {
    '+': 'ideal_clk',      # 1-bit (was '&')
    'V': 'div_out_raw',    # 1-bit (was 'Q')
    'X': 'div_out_dtc',    # 1-bit (was 'S')
    'N"': 'comp_3rd',      # 13-bit
    '*': 'comp_2rd_tb',    # 16-bit (testbench verify)
}
vec_widths = {'comp_3rd': 13, 'comp_2rd_tb': 16}

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

time = 0
cur = {nm: '0' for nm in target_ids.values()}
prev = {'ideal_clk': 'x', 'div_out_raw': 'x', 'div_out_dtc': 'x'}
clk_edges = {'ideal_clk': [], 'div_out_raw': [], 'div_out_dtc': []}
vcd_at_raw = []  # (time, comp_3rd, comp_2rd_tb)

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
                nm = target_ids.get(id_str)
                if nm in prev and val == '1' and prev[nm] != '1':
                    clk_edges[nm].append(time)
                    if nm == 'div_out_raw':
                        vcd_at_raw.append((time,
                            cur.get('comp_3rd','x'), cur.get('comp_2rd_tb','x')))
                if nm in prev:
                    prev[nm] = val
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
                nm = target_ids.get(id_str)
                if nm in vec_widths:
                    cur[nm] = bits
    else:
        i += 1

def to_signed(bits, w):
    if not bits or bits[0] not in '01': return bits
    v = int(bits, 2)
    if v >= (1 << (w-1)): v -= (1 << w)
    return str(v)

ideal = clk_edges['ideal_clk']
raw = clk_edges['div_out_raw']
dtc = clk_edges['div_out_dtc']

rows = []
ii, di = 0, 0
for idx, rt in enumerate(raw):
    while ii < len(ideal) - 1 and ideal[ii + 1] <= rt:
        ii += 1
    it = ideal[ii] if ideal[ii] <= rt else None
    while di < len(dtc) - 1 and dtc[di + 1] < rt:
        di += 1
    if di + 1 < len(dtc) and (dtc[di + 1] - rt) < (rt - dtc[di]):
        di += 1
    dt_val = dtc[di]
    c3 = vcd_at_raw[idx][1] if idx < len(vcd_at_raw) else 'x'
    c2tb = vcd_at_raw[idx][2] if idx < len(vcd_at_raw) else 'x'
    rows.append((it, rt, dt_val, c3, c2tb))

print(f'Total: ideal={len(ideal)} raw={len(raw)} dtc={len(dtc)}')

max_t = raw[-1]
start_t = max_t - 100000000
rows = [r for r in rows if r[1] >= start_t]
print(f'Last 100us: {len(rows)} cycles')

with open(csv_path, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['ideal_clk_ps', 'div_out_raw_ps', 'div_out_dtc_ps', 'comp_3rd', 'comp_2rd_tb'])
    for it, rt, dt, c3, c2tb in rows:
        w.writerow([it, rt, dt, to_signed(c3, 13), to_signed(c2tb, 16)])

print(f'\nCSV: {csv_path}')
with open(csv_path, 'r') as f:
    lines = f.readlines()
    for line in lines[:10]:
        print(f'  {line.strip()}')
    print(f'  ...')
    for line in lines[-3:]:
        print(f'  {line.strip()}')
