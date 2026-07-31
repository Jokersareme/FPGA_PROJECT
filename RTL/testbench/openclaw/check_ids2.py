import re
with open(r'.\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+(\S+)\s*\$end', header):
    idc, nm = m.group(1), m.group(2)
    if nm in ('ideal_clk', 'div_out_dtc', 'div_out_raw', 'dout', 'div_out_dtc_g',
              'sys_clk_g', 'div_out_raw_g'):
        print(f'id={idc!r:6s} name={nm}')
