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
        w = int(m.group(4))
        full = '.'.join(scope_stack[1:] + [nm])
        if 'eo_dly' in full.lower() or 'E_combined' in full:
            print(f'  id={idc!r:6s} w={w:2d}  {full}')
        # Also find the actual E_combined signal
        if 'E_combined' in full:
            print(f'  >>> E_combined id={idc!r}')
