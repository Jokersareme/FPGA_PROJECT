import re
with open(r'.\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Match 1S or 0S where S followed by non-printable or delimiter
rise = len(re.findall(r'1S(?:\s|#|[^!-~]|\Z)', body))
fall = len(re.findall(r'0S(?:\s|#|[^!-~]|\Z)', body))
print(f'DTC (id=S) rising={rise} falling={fall}')

rrise = len(re.findall(r'1Q(?:\s|#|[^!-~]|\Z)', body))
rfall = len(re.findall(r'0Q(?:\s|#|[^!-~]|\Z)', body))
print(f'Raw (id=Q) rising={rrise} falling={rfall}')
