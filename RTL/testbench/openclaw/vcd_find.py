# Export waveform data to CSV - fixed VCD parser, different output path
import re, csv, os

vcd = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"
csv_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\mash3_waveform.csv"

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

# Print targets with exact IDs
for idc, (nm, full, w) in sorted(var_map.items()):
    bl = full.lower()
    if 'ideal_clk' in bl or 'sys_bufg_fracn_out.i' in bl or 'u_fracn_div.e_combined' in bl:
        print(f"  id={idc!r:4s} w={w:2d}  {full}")

# Also print just to find more Fout signals
print("\n=== Fout/div_out related ===")
for idc, (nm, full, w) in sorted(var_map.items()):
    if any(k in full for k in ['div_out_raw_g', 'div_out_raw', 'fracn_out.O', 'fracn_out.I']):
        print(f"  id={idc!r:4s} w={w:2d}  {full}")
