import re
with open(r'.\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+(\S+)\s*\$end', header):
    idc = m.group(1)
    if 'S' in idc or 'Q' in idc:
        print(f'  id={idc!r:6s} name={m.group(2)}')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Count: 1S/0S followed by non-printable or space/#/
# S at end of a scalar means next char is not printable ID char
dtc_rise = len(re.findall(r'1S(?=[\s#\r\n0123456789]|\Z)', body))
dtc_fall = len(re.findall(r'0S(?=[\s#\r\n0123456789]|\Z)', body))
raw_rise = len(re.findall(r'1Q(?=[\s#\r\n0123456789]|\Z)', body))
raw_fall = len(re.findall(r'0Q(?=[\s#\r\n0123456789]|\Z)', body))
print(f'\nDTC (id=S) rising={dtc_rise} falling={dtc_fall}')
print(f'Raw (id=Q) rising={raw_rise} falling={raw_fall}')
