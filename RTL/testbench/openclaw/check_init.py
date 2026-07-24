# Check initial values and first transitions
import re

with open('tb_quick_3rd.vcd', 'r') as f:
    c = f.read()

header = c[:c.find('$dumpvars')]
body = c[c.find('$end', c.find('$dumpvars')) + 4:]

scope_stack = ['']
var_map = {}
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
                     r'\$var (\w+) (\d+) (\S+) (\S+)', header):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        _, w, idc, nm = m.group(3), m.group(4), m.group(5), m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        var_map[idc] = (nm, full, int(w))

# Show initial value dump (just after $dumpvars)
init_part = body[:2000]
print("=== Initial dump section ===")
print(init_part[:500])

# Check what's at the very first few time points
entries = re.findall(r'#(\d+)\s+(.*?)(?=#|\Z)', body)
print(f"\nTotal entries: {len(entries)}")
print(f"\nFirst 3 time entries:")
for i, (t, vals) in enumerate(entries[:3]):
    print(f"\n  T={t}ps:")
    # Show first 300 chars of each entry
    for line in vals.split('\n'):
        l = line.strip()
        if l:
            print(f"    {l[:120]}")

# Search for state signal in the dump
state_id = '."'  # from earlier analysis
print(f"\n=== Search for state id {state_id!r} in body ===")
for t, vals in entries[:10]:
    if state_id in vals:
        print(f"  Found at T={t}ps")

# Check rst_n_dtc / reset status
rst_ids = [(idc, f) for idc, (nm, f, w) in var_map.items() if 'rst_n_dtc' in f or 'and_rst_n_dtc' in f]
print(f"\nrst_n_dtc signals: {rst_ids}")
