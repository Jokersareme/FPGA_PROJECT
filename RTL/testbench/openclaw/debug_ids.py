import re
with open(r'.\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')
header = txt[:txt.find('$dumpvars')]
all_ids = set()
for m in re.finditer(r'\$var\s+\w+\s+\d+\s+(\S+)\s+\S+\s*\$end', header):
    all_ids.add(m.group(1))
# Check
targets = ['J"', 'f"', 'g"']
for t in targets:
    print(f'{t!r} in all_ids: {t in all_ids}')
# Find occurrence in body
body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]
for t in targets:
    idx = body.find(t)
    if idx >= 0:
        ctx = body[max(0,idx-30):idx+10]
        print(f'  Example: ...{repr(ctx)}...')
