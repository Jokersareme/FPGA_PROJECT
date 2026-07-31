import re
with open(r'.\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# For single-char ID S: followed by space, tab, CR, LF, #, or end
# NOT followed by another printable char
dtc_rise = len(re.findall(r'1S[\s#\r\n]', body))
dtc_fall = len(re.findall(r'0S[\s#\r\n]', body))
print(f'DTC (id=S) rising={dtc_rise} falling={dtc_fall}')

raw_rise = len(re.findall(r'1Q[\s#\r\n]', body))
raw_fall = len(re.findall(r'0Q[\s#\r\n]', body))
print(f'Raw (id=Q) rising={raw_rise} falling={raw_fall}')
