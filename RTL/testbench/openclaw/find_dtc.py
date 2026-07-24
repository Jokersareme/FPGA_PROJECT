"""Extract ideal_clk, div_out_raw, div_out_dtc rising edges"""
import re, os

vcd = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"

with open(vcd, 'rb') as f:
    txt = f.read().decode('latin-1')

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

# Print all 1-bit signals with "dtc" in name
print("Signals with dtc:")
for idc, (nm, full, w) in sorted(var_map.items()):
    if 'dtc' in full.lower() and w == 1:
        print(f"  id={idc!r:4s}  {full}")

# Also look for lut_dtc_top.dout and carry_dout
for idc, (nm, full, w) in var_map.items():
    if 'u_lut_dtc_top.dout' in full or 'carry_dout' in full:
        print(f"  id={idc!r:4s} w={w} {full}")
