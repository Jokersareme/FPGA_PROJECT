# Fast VCD export - char-by-char for last 80us
import csv, os

vcd = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"
csv_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\mash3_waveform.csv"

with open(vcd, 'rb') as f:
    txt = f.read().decode('latin-1')

# Build variable map from header to confirm IDs
import re as _re
scope_stack = ['']
var_map = {}
for m in _re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
    r'\$var (\w+) (\d+) (\S+) (\S+)', txt[:txt.find('$dumpvars')]):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        _, w, idc, nm = m.group(3), m.group(4), m.group(5), m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        var_map[idc] = (nm, full, int(w))

# Find: ideal_clk, div_out_raw/Fout, E_combined
target_ids = {}
for idc, (nm, full, w) in var_map.items():
    if 'ideal_clk' in full:
        target_ids['ideal_clk'] = (idc, w)
    if 'div_out_raw' in full or 'u_sys_bufg_fracn_out.I' in full:
        target_ids['div_out_raw'] = (idc, w)
    if 'u_fracn_div.E_combined' in full:
        target_ids['E_combined'] = (idc, w)

print("== Target signals ==")
for name, (idc, w) in target_ids.items():
    print(f"  {name}: id={idc!r:10s} w={w}")

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# First pass: find max time and determine last 80us boundary
max_time = 0
i = 0
while i < len(body):
    if body[i] == '#':
        j = i + 1
        while j < len(body) and body[j].isdigit():
            j += 1
        if j > i + 1:
            t = int(body[i+1:j])
            max_time = max(max_time, t)
        i = j
    else:
        i += 1

start_time = max_time - 80000000
print(f"Max time: {max_time/1e6:.1f}us")
print(f"Export from: {start_time/1e6:.1f}us")

# Second pass: parse values, only track last 80us
iclk_id = target_ids.get('ideal_clk', (None, 0))[0]
fout_id = target_ids.get('div_out_raw', (None, 0))[0]
ec_id = target_ids.get('E_combined', (None, 0))[0]

# Extract single-char IDs
iclk_single = len(iclk_id) == 1 if iclk_id else False
fout_single = len(fout_id) == 1 if fout_id else False
ec_single = len(ec_id) == 1 if ec_id else False

cur_iclk = 'x'
cur_fout = 'x'
cur_ec = 'x'
prev_iclk = 'x'
prev_fout = 'x'
in_range = False
ideal_edges = []
fout_edges = []

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
            if time >= start_time and not in_range:
                in_range = True
        i = j
    elif c in '01xz':
        val = c
        i += 1
        # Read ID: skip optional whitespace, then read printable chars
        while i < len(body) and body[i] in ' \t\r\n':
            i += 1
        id_start = i
        while i < len(body) and body[i].isprintable() and body[i] not in ' \t\r\n#':
            i += 1
        id_str = body[id_start:i]
        exact = val + id_str  # full VCD token
        
        if iclk_id and exact == iclk_id:
            cur_iclk = val
        if fout_id and exact == fout_id:
            cur_fout = val
        # For multi-char IDs, we might need different matching
        
    elif c == 'b':
        i += 1
        bits = ''
        while i < len(body) and body[i] in '01xz':
            bits += body[i]
            i += 1
        # Skip whitespace before ID
        while i < len(body) and body[i] in ' \t\r\n':
            i += 1
        id_start = i
        while i < len(body) and body[i].isprintable() and body[i] not in ' \t\r\n#':
            i += 1
        id_str = body[id_start:i]
        
        if ec_id and id_str == ec_id:
            cur_ec = bits
    else:
        i += 1
    
    if in_range and time != (prev_time := (prev_time if 'prev_time' in dir() else -1)):
        # Process edge detection at each time we have values
        if cur_iclk == '1' and prev_iclk != '1':
            ec_str = cur_ec
            if len(ec_str) > 1 and ec_str[0] in '01':
                try:
                    v = int(ec_str, 2)
                    if v >= 0x1000: v -= 0x2000
                    ec_str = str(v)
                except: pass
            ideal_edges.append((time, cur_iclk, cur_fout, ec_str))
        if cur_fout == '1' and prev_fout != '1':
            ec_str = cur_ec
            if len(ec_str) > 1 and ec_str[0] in '01':
                try:
                    v = int(ec_str, 2)
                    if v >= 0x1000: v -= 0x2000
                    ec_str = str(v)
                except: pass
            fout_edges.append((time, cur_iclk, cur_fout, ec_str))
        prev_iclk = cur_iclk
        prev_fout = cur_fout
        prev_time = time

    if not in_range:
        if iclk_id:
            # Must update prev values for edge detection later
            pass

print(f"ideal_clk edges: {len(ideal_edges)}, Fout edges: {len(fout_edges)}")

if not fout_edges:
    print("\nWARNING: No Fout edges found!")
    print(f"  fout_id = {fout_id!r}")
    print(f"  Searching for id in body...")
    # Search for the Fout ID in the body
    if fout_id:
        cnt = body.count(fout_id)
        print(f"  ID {fout_id!r} appears {cnt} times in body")
    # Also look for any ID that ends with Q
    for idc, (nm, full, w) in var_map.items():
        if 'div_out' in full.lower() or 'fout' in full.lower() or 'Fout' in full:
            print(f"  Found: {full} -> id={idc!r}")

if not fout_edges and not ideal_edges:
    print("No edges found at all. Using fallback approach...")
    # Let me just dump first 10 entries from body
    i = 0
    count = 0
    while i < len(body) and count < 20:
        if body[i] == '#':
            j = i+1
            while j < len(body) and body[j].isdigit(): j += 1
            t = body[i+1:j]
            i = j
            # Show next 100 chars
            chunk = body[i:i+200]
            print(f"  T={t}: ...{repr(chunk[:100])}...")
            count += 1
        else:
            i += 1
