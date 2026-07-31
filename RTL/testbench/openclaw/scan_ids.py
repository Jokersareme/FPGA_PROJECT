import re
with open('tb_quick_3rd.vcd', 'rb') as f:
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
        idc = m.group(5)
        nm = m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        keywords = ['ideal_clk', 'div_out_raw', 'div_out_dtc', 'comp_3rd',
                     'comp_2rd_tb', 'd_delta_sigma', 'sum_eo1', 'sum_eo2',
                     'E_combined', 'comp_2rd']
        for kw in keywords:
            if kw in full:
                print(f'  {kw:20s}  id={idc!r:6s}  {full}')
                break
