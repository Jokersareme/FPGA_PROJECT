"""Export: each column is independent. ideal_clk | raw | dtc | fracn_at_raw"""
import re, csv, os

vcd_path = r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd'
csv_path = r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\waveform_export.csv'

with open(vcd_path, 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]

all_ids = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+', header):
    all_ids.add(m.group(1))

target_ids = {'&': 'ideal_clk', 'Q': 'div_out_raw', 'S': 'div_out_dtc',
              'J"': 'comp_3rd', 'f"': 'sum_eo1', 'g"': 'sum_eo2'}

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

time = 0
cur = {nm: 'x' for nm in target_ids.values()}
prev = {'ideal_clk': 'x', 'div_out_raw': 'x', 'div_out_dtc': 'x'}

ideal_edges = []
raw_edges = []
dtc_edges = []
fracn_at_raw = []  # (t, c3, s1, s2) at each raw rising edge

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
                if i + 1 < len(body) and body[i:i+2] in all_ids:
                    id_str = body[i:i+2]; i += 2
                elif nxt in all_ids:
                    id_str = nxt; i += 1
                else:
                    i += 1; continue
                
                nm = target_ids.get(id_str)
                if nm == 'ideal_clk':
                    if val == '1' and prev[nm] != '1':
                        ideal_edges.append(time)
                    prev[nm] = val
                elif nm == 'div_out_raw':
                    if val == '1' and prev[nm] != '1':
                        raw_edges.append(time)
                        fracn_at_raw.append((time, cur['comp_3rd'], cur['sum_eo1'], cur['sum_eo2']))
                    prev[nm] = val
                elif nm == 'div_out_dtc':
                    if val == '1' and prev[nm] != '1':
                        dtc_edges.append(time)
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
                if i + 1 < len(body) and body[i:i+2] in all_ids:
                    id_str = body[i:i+2]; i += 2
                elif nxt in all_ids:
                    id_str = nxt; i += 1
                else:
                    i += 1; continue
                nm = target_ids.get(id_str)
                if nm in ('comp_3rd', 'sum_eo1', 'sum_eo2'):
                    cur[nm] = bits
    else:
        i += 1

# Last 100us
max_t = max(ideal_edges[-1], raw_edges[-1], dtc_edges[-1])
start_t = max_t - 100000000

ideal_e = [t for t in ideal_edges if t >= start_t]
raw_e = [t for t in raw_edges if t >= start_t]
dtc_e = [t for t in dtc_edges if t >= start_t]
fracn_e = [(t, c3, s1, s2) for t, c3, s1, s2 in fracn_at_raw if t >= start_t]

print(f'ideal_clk: {len(ideal_e)}, div_out_raw: {len(raw_e)}, div_out_dtc: {len(dtc_e)}')
print(f'fracn snapshots: {len(fracn_e)}')

def to_signed(bits, w):
    if not bits or bits[0] not in '01': return bits
    v = int(bits, 2)
    if v >= (1 << (w-1)): v -= (1 << w)
    return str(v)

# Build fracn lookup by time (each raw edge has one snapshot)
fracn_map = {}
for t, c3, s1, s2 in fracn_e:
    fracn_map[t] = (c3, s1, s2)

# Write: max rows = max length of any column
max_rows = max(len(ideal_e), len(raw_e), len(dtc_e))

with open(csv_path, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['ideal_clk_ps', 'ideal_clk_us',
                'div_out_raw_ps', 'div_out_raw_us',
                'div_out_dtc_ps', 'div_out_dtc_us',
                'comp_3rd', 'sum_eo1', 'sum_eo2'])
    
    for i in range(max_rows):
        it = ideal_e[i] if i < len(ideal_e) else ''
        rt = raw_e[i] if i < len(raw_e) else ''
        dtc = dtc_e[i] if i < len(dtc_e) else ''
        
        c3 = s1 = s2 = ''
        if rt and rt in fracn_map:
            c3b, s1b, s2b = fracn_map[rt]
            c3 = to_signed(c3b, 13)
            s1 = to_signed(s1b, 13)
            s2 = to_signed(s2b, 13)
        
        w.writerow([
            it, f'{it/1e6:.3f}' if it else '',
            rt, f'{rt/1e6:.3f}' if rt else '',
            dtc, f'{dtc/1e6:.3f}' if dtc else '',
            c3, s1, s2])

print(f'\nCSV: {csv_path}')
print(f'Rows: {max_rows}')
# Show first 10
with open(csv_path, 'r') as f:
    for i, line in enumerate(f):
        if i > 10: break
        print(f'  {line.strip()}')
