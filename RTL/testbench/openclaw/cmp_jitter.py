# Compare raw vs dtc jitter
import re, numpy as np

with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

time = 0
raw_edges = []
dtc_edges = []
prev_raw = 'x'
prev_dtc = 'x'

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
    elif c in '01':
        val = c
        i += 1
        j = i
        while j < len(body) and body[j].isprintable() and body[j] not in ' \t\r\n#b':
            j += 1
        id_str = body[i:j]
        i = j
        if id_str == 'Q':
            if val == '1' and prev_raw != '1':
                raw_edges.append(time)
            prev_raw = val
        elif id_str == 'S':
            if val == '1' and prev_dtc != '1':
                dtc_edges.append(time)
            prev_dtc = val
    else:
        i += 1

max_t = max(raw_edges[-1], dtc_edges[-1])
start_t = max_t - 80000000
raw_e = [t for t in raw_edges if t >= start_t]
dtc_e = [t for t in dtc_edges if t >= start_t]

print(f'Ray edges: {len(raw_e)}, DTC edges: {len(dtc_e)}')
raw_per = np.diff(raw_e)
dtc_per = np.diff(dtc_e[:len(raw_e)])

print(f'Raw period: mean={np.mean(raw_per):.0f}ps std={np.std(raw_per):.0f}ps')
print(f'DTC period: mean={np.mean(dtc_per):.0f}ps std={np.std(dtc_per):.0f}ps')

raw_c2c = np.diff(raw_per)
dtc_c2c = np.diff(dtc_per)
print(f'Raw c2c jitter:  std={np.std(raw_c2c):.0f}ps  max| |={np.max(np.abs(raw_c2c)):.0f}ps')
print(f'DTC c2c jitter:  std={np.std(dtc_c2c):.0f}ps  max| |={np.max(np.abs(dtc_c2c)):.0f}ps')
print(f'DTC improvement: std {100*(1-np.std(dtc_c2c)/np.std(raw_c2c)):.0f}%')
