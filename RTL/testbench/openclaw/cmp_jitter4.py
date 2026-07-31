import re, numpy as np

with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

entries = re.findall(r'#(\d+)\s*(.*?)(?=#|\Z)', body, re.DOTALL)

cur_dtc = 'x'
cur_raw = 'x'
dtc_edges = []
raw_edges = []

for t_str, vals in entries:
    t = int(t_str)
    
    # Match: value(0/1) + 1-char ID + next char being value/delim/#
    # Single-char ID means next char is 0/1 (new value), space, #, newline, or end
    for m in re.finditer(r'([01])([!-~])(?=[01#\s\r\n]|\Z)', vals):
        val = m.group(1)
        idc = m.group(2)
        if idc == 'S':
            if val == '1' and cur_dtc != '1':
                dtc_edges.append(t)
            cur_dtc = val
        elif idc == 'Q':
            if val == '1' and cur_raw != '1':
                raw_edges.append(t)
            cur_raw = val

max_t = max(raw_edges[-1], dtc_edges[-1]) if raw_edges and dtc_edges else 0
start_t = max_t - 80000000

raw_e = [t for t in raw_edges if t >= start_t]
dtc_e = [t for t in dtc_edges if t >= start_t]

n = min(len(raw_e), len(dtc_e))
raw_e = raw_e[:n]
dtc_e = dtc_e[:n]

print(f'Raw edges: {len(raw_e)}, DTC edges: {len(dtc_e)}')
raw_per = np.diff(raw_e)
dtc_per = np.diff(dtc_e)
print(f'Raw period: mean={np.mean(raw_per):.0f}ps  std={np.std(raw_per):.0f}ps')
print(f'DTC period: mean={np.mean(dtc_per):.0f}ps  std={np.std(dtc_per):.0f}ps')

raw_c2c = np.diff(raw_per)
dtc_c2c = np.diff(dtc_per)
print(f'Raw c2c: std={np.std(raw_c2c):.0f}  max||={np.max(np.abs(raw_c2c)):.0f}')
print(f'DTC c2c: std={np.std(dtc_c2c):.0f}  max||={np.max(np.abs(dtc_c2c)):.0f}')
print(f'DTC improvement: {100*(1-np.std(dtc_c2c)/np.std(raw_c2c)):.0f}%')

print(f'\nFirst 10 edges:')
for i in range(min(10, len(raw_e))):
    delay = dtc_e[i] - raw_e[i]
    print(f'  raw={raw_e[i]:10d}  dtc={dtc_e[i]:10d}  delay={delay:8d}ps')
