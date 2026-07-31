import re

with open('tb_top_auto_full.vcd', 'r') as f:
    content = f.read()

body = content[content.find('$end', content.find('$dumpvars')) + 5:]

print("=== All signal changes between T=1.3us and T=1.6us ===")
lines = body.split('\n')
curr_time = 0
line_count = 0

for line in lines:
    if line.startswith('#'):
        try: curr_time = int(line[1:])
        except: pass
        continue
    if not (1300000 < curr_time < 1600000):
        continue
    
    # Print every line that contains a b<value> or scalar change
    if line.strip():
        print(f"  T={curr_time/1000:6.2f}us: {line.strip()[:100]}")
        line_count += 1

print(f"\nTotal signal changes in range: {line_count}")
