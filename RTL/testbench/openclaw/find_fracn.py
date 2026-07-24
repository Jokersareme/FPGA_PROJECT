"""Find comp_3rd, sum_eo1, sum_eo2 in VCD"""
import re

with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]

scope_stack = ['']
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
                     r'\$var (\w+) (\d+) (\S+) (\S+)', header):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        t = m.group(3)
        w = int(m.group(4))
        idc = m.group(5)
        nm = m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        if any(k in full.lower() for k in ['comp_3rd', 'sum_eo', 'sum_r', '.e_o_1', '.e_o_2', '.e_o_3']):
            print(f'  id={idc!r:8s} w={w:2d}  {full}')
