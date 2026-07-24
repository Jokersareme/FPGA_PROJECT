import re
with open('tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+(\S+)', header):
    nm = m.group(2)
    if any(k in nm for k in ['comp_2rd_tb', 'carry_2', 'carry_3', 'c2_d1', 'c3_d1', 'Eo_d1']):
        print(f'  id={m.group(1)!r:6s} w= {nm}')
