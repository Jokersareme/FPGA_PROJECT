import re, statistics

with open('tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]

# Find key signal IDs
ids = {}
scope_stack = ['']
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
                     r'\$var (\w+) (\d+) (\S+) (\S+)', header):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        idc = m.group(5)
        nm = m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        if 'div_out_dtc' in full and full.endswith('div_out_dtc') and 'g' not in full:
            ids['dtc'] = idc
            print(f'div_out_dtc: id={idc!r}')
        if 'ideal_clk' in full and 'tb_quick_3rd.ideal_clk' == full:
            ids['ideal'] = idc
            print(f'ideal_clk: id={idc!r}')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

all_ids_set = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+', header):
    all_ids_set.add(m.group(1))

# Extract dtc rising edges
dtc_edges = []
ideal_edges = []
time = 0
prev_dtc = 'x'
prev_ideal = 'x'

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
                id_str = body[i:i+2] if (i+1 < len(body) and body[i:i+2] in all_ids_set) else nxt
                i += 2 if id_str == body[i:i+2] else 1
                if id_str == ids.get('dtc') and val == '1' and prev_dtc != '1':
                    dtc_edges.append(time)
                    prev_dtc = val
                elif id_str == ids.get('dtc'):
                    prev_dtc = val
                if id_str == ids.get('ideal') and val == '1' and prev_ideal != '1':
                    ideal_edges.append(time)
                    prev_ideal = val
                elif id_str == ids.get('ideal'):
                    prev_ideal = val
    elif c == 'b':
        i += 1
        bits = ''
        while i < len(body) and body[i] in '01xzXZ':
            bits += body[i]; i += 1
        while i < len(body) and body[i] in ' \t\r\n':
            i += 1
        i += 2  # skip ID
    else:
        i += 1

# Calculate periods and jitter from last 100us
max_t = max(dtc_edges)
start_t = max_t - 100000000
dtc_in_window = [t for t in dtc_edges if t >= start_t]
ideal_in_window = [t for t in ideal_edges if t >= start_t]

dtc_periods = [dtc_in_window[i+1] - dtc_in_window[i] for i in range(len(dtc_in_window)-1)]
ideal_periods = [ideal_in_window[i+1] - ideal_in_window[i] for i in range(len(ideal_in_window)-1)]

ideal_mean = statistics.mean(ideal_periods)

print(f'\nDTC edges in last 100us: {len(dtc_in_window)}')
print(f'DTC periods: {len(dtc_periods)}')
print(f'\n=== DTC Cycle-to-Cycle Jitter ===')
print(f'  Mean period: {statistics.mean(dtc_periods)/1000:.3f} ns')
print(f'  Std Dev:     {statistics.stdev(dtc_periods)/1000:.3f} ns')
print(f'  Peak-Peak:   {(max(dtc_periods)-min(dtc_periods))/1000:.3f} ns')
print(f'  Min period:  {min(dtc_periods)/1000:.3f} ns')
print(f'  Max period:  {max(dtc_periods)/1000:.3f} ns')

# Cycle-to-cycle jitter: abs(period[n] - period[n-1])
cc_jitter = [abs(dtc_periods[i+1] - dtc_periods[i]) for i in range(len(dtc_periods)-1)]
print(f'\n=== Cycle-to-Cycle (C-C) Jitter ===')
print(f'  Mean:  {statistics.mean(cc_jitter)/1000:.3f} ns')
print(f'  Std:   {statistics.stdev(cc_jitter)/1000:.3f} ns')
print(f'  Max:   {max(cc_jitter)/1000:.3f} ns')
print(f'  PkPk:  {(max(cc_jitter)-min(cc_jitter))/1000:.3f} ns')

# Compare with ideal
ideal_cc = [abs(ideal_periods[i+1] - ideal_periods[i]) for i in range(len(ideal_periods)-1)]
print(f'\nIdeal clock C-C jitter:')
print(f'  Mean:  {statistics.mean(ideal_cc)/1000:.3f} ns')
print(f'  Max:   {max(ideal_cc)/1000:.3f} ns')
