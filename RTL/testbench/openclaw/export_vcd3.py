# Export waveform data to CSV - fixed VCD parser
import re, csv

vcd = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"
csv_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\waveform_export.csv"

with open(vcd, 'rb') as f:
    data = f.read()
txt = data.decode('latin-1')

# Build var map from header
scope_stack = ['']
var_map = {}
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
                     r'\$var (\w+) (\d+) (\S+) (\S+)', txt[:txt.find('$dumpvars')]):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        _, w, idc, nm = m.group(3), m.group(4), m.group(5), m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        var_map[idc] = (nm, full, int(w))

# Target: ideal_clk(&), div_out_raw(Q), E_combined(R")
# VCD format: scalar = <val><id>, vector = b<bits><id>
track = {
    '&':  ('ideal_clk', 1),
    'Q':  ('div_out_raw', 1),
    'R"': ('E_combined', 13),
}

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Parse: split into time entries
entries = re.split(r'#(\d+)\s*', body)[1:]  # skip first empty, rest: [time, vals, time, vals, ...]

cur = {name: 'x' for name, _ in track.values()}
rows = []  # (time, ideal_clk, div_out_raw, E_combined)

# Function to parse scalar VCD line: "1&" or "0Q"
def parse_one(line, idc, bits):
    if bits == 1:
        # Scalar: value is first char, then ID follows immediately: "1&"
        if len(line) >= len(idc) + 1:
            val = line[0]
            rest = line[1:]
            if val in '01xXzZ' and rest == idc:
                return val
        return None
    else:
        # Vector: b<binary_value><idc>
        if line.startswith('b'):
            bits_str = ''
            idx = 1
            while idx < len(line) and line[idx] in '01xXzZ':
                bits_str += line[idx]
                idx += 1
            rest = line[idx:]
            if len(bits_str) == bits and rest == idc:
                return bits_str
        return None

for i in range(0, len(entries), 2):
    t = int(entries[i])
    vals_chunk = entries[i+1]
    
    changed = False
    for idc, (name, bits) in track.items():
        # Search in vals_chunk for the value pattern
        if bits == 1:
            # Try all positions: look for <val><idc>
            for pos in range(len(vals_chunk) - len(idc)):
                val = vals_chunk[pos]
                if val in '01xz':
                    if vals_chunk[pos+1:pos+1+len(idc)] == idc:
                        if cur[name] != val:
                            cur[name] = val
                            changed = True
                        break
        else:
            # Vector: b<value><idc>
            for m in re.finditer(r'b([01xz]+)' + re.escape(idc), vals_chunk):
                val = m.group(1)
                if len(val) == bits:
                    if cur[name] != val:
                        cur[name] = val
                        changed = True
                    break
    
    if changed:
        ec = cur['E_combined']
        if len(ec) > 1 and ec[0] in '01':
            ec_int = int(ec, 2)
            if ec_int >= 0x1000:
                ec_int -= 0x2000
            ec_disp = str(ec_int)
        else:
            ec_disp = ec
        rows.append((t, cur['ideal_clk'], cur['div_out_raw'], ec_disp))

# Only output samples on Fout rising edges
last_fout = 'x'
filtered = []
for t, clk, fout, ec in rows:
    if fout == '1' and last_fout != '1':
        filtered.append((t, clk, fout, ec))
    last_fout = fout

# Write CSV
with open(csv_path, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['time_ps', 'time_us', 'ideal_clk', 'div_out_raw', 'E_combined'])
    for t, clk, fout, ec in filtered:
        w.writerow([t, t/1000, clk, fout, ec])

print(f"Written {len(filtered)} rows (Fout rising edges) to {csv_path}")
import os
print(f"File size: {os.path.getsize(csv_path)/1024:.0f} KB")
