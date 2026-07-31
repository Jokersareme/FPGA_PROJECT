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
        t = m.group(3)
        w = int(m.group(4))
        idc = m.group(5)
        nm = m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        if any(k in full.lower() for k in ['comp_2rd', 'comp_3rd', 'd_delta', 'sum_eo',
                                            'ideal_clk', 'div_out_raw', 'div_out_dtc']):
            print(f'  id={idc!r:6s} w={w:2d}  {full}')
