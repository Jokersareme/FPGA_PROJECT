import re
with open('tb_quick_3rd.vcd','r') as f:
    c = f.read()
h = c[:c.find('$dumpvars')]
for m in re.finditer(r'\$var.*?([a-zA-Z_]\S+)\s*\$end', h):
    name = m.group(1)
    low = name.lower()
    if any(k in low for k in ['state','cal','gain','done','busy','count','quot','divid','divis','wait','next']):
        print(m.group()[:120])
