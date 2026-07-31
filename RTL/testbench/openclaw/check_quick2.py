# Quick VCD scan
import re

with open("tb_quick_3rd.vcd", "r") as f:
    content = f.read()

# Print all scope/variable definitions up to $dumpvars
header = content[:content.find('$dumpvars')]
print(header[:3000])
