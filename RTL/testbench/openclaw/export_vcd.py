# Export ideal_clk, Fout(div_out_raw), E_combined to CSV
# Only capture on Fout rising edges (one sample per cycle)
import re, csv, os

vcd_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"
csv_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\waveform_export.csv"

with open(vcd_path, 'r', encoding='latin-1') as f:
    content = f.read()

header = content[:content.find('$dumpvars')]
body = content[content.find('$end', content.find('$dumpvars')) + 4:]

# Build var map
scope_stack = ['']
var_map = {}
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
                     r'\$var (\w+) (\d+) (\S+) (\S+)', header):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        _, w, idc, nm = m.group(3), m.group(4), m.group(5), m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        var_map[idc] = (nm, full, int(w))

# Target signals
targets = {
    'ideal_clk': None,          # id='&'
    'Fout': None,               # div_out_raw
    'E_combined': None,         # u_fracn_div.E_combined
}

for idc, (nm, full, w) in var_map.items():
    if full.endswith('.ideal_clk'):
        targets['ideal_clk'] = idc
    if 'u_fracn_div.E_combined' in full or 'u_fracn_div.E_combined' == nm:
        targets['E_combined'] = idc
    if full.endswith('div_out_raw') or (full.endswith('div_out_raw_g') and 'u_sys_bufg_fracn_out.O' in full):
        targets['Fout'] = idc
    # Also check u_sys_bufg_fracn_out.I for raw div_out
    if full.endswith('u_sys_bufg_fracn_out.I') or full.endswith('u_sys_bufg_fracn_out.O'):
        targets['Fout'] = idc  # O is div_out_raw_g

print("=== Target IDs ===")
for name, idc in targets.items():
    if idc:
        print(f"  {name}: id={idc!r}")
    else:
        print(f"  {name}: NOT FOUND")

# Find the Fout signal explicitly
print("\n=== Searching for Fout/div_out signals ===")
for idc, (nm, full, w) in sorted(var_map.items()):
    if any(k in full for k in ['div_out', 'Fout', 'f45', 'Fdiv', 'sys_bufg_fracn']):
        print(f"  id={idc!r:4s} w={w:2d}  {full}")

# Check what ideal_clk is
if targets['ideal_clk']:
    idc = targets['ideal_clk']
    print(f"\nideal_clk id={idc!r}")

print(f"\n=== Fout search ===")
for idc, (nm, full, w) in sorted(var_map.items()):
    bl = full.lower()
    if 'div_out_raw_g' in bl or 'div_out_raw' == nm or 'fout' in bl:
        print(f"  id={idc!r:4s} w={w:2d}  {full}")

# Check all tb_quick_3rd top-level signals
print(f"\n=== Top-level signals ===")
for idc, (nm, full, w) in sorted(var_map.items()):
    parts = full.split('.')
    if len(parts) == 2 and parts[0] == 'tb_quick_3rd':
        print(f"  id={idc!r:4s} w={w:2d}  {full}")
