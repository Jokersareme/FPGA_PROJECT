import re
with open(r'.\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# 1S not followed by printable non-whitespace (i.e. no continuation of 2-char ID)
dtc_rise = len(re.findall(r'1S(?![!-~])', body))
dtc_fall = len(re.findall(r'0S(?![!-~])', body))
print(f'DTC (id=S) rising={dtc_rise} falling={dtc_fall}')

raw_rise = len(re.findall(r'1Q(?![!-~])', body))
raw_fall = len(re.findall(r'0Q(?![!-~])', body))
print(f'Raw (id=Q) rising={raw_rise} falling={raw_fall}')
