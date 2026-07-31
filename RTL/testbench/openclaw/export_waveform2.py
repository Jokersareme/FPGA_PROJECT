# Extract clock, Fout, and E_combined to CSV
import re, csv, os

vcd_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"
csv_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\waveform_export.csv"

with open(vcd_path, 'r', encoding='latin-1') as f:
    content = f.read()

header = content[:content.find('$dumpvars')]
body = content[content.find('$end', content.find('$dumpvars')) + 4:]

# Build variable map
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

# Print ALL signals
print("=== ALL VCD Signals ===")
for idc, (nm, full, w) in sorted(var_map.items()):
    print(f"  id={idc!r:4s} w={w:2d}  {full}")
