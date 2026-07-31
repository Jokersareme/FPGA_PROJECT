# VCD state machine analysis - search whole file for state transitions
import re

with open('tb_quick_3rd.vcd', 'rb') as f:
    data = f.read()

# Search for calibrator state signal (should appear as 4-bit binary)
# The state id from earlier was '.' and '"' 
# Look for all state variable declarations
text = data.decode('latin-1')
header = text[:text.find('$dumpvars')]

# Find all $var lines that mention 'state' or 'u_cal'
import re
for m in re.finditer(r'\$var.*?state.*?\$end', header):
    print(f"State var: {m.group()}")

# Search for the literal id of the state variable
# The ID was ." which is 2 characters - let me find it via scope path
for m in re.finditer(r'\.u_cal\.(\w+)', header):
    name = m.group(1)
    # Find the $var for this name
    pos = m.start()
    # Search backward for $var
    var_start = header.rfind('$var', 0, pos)
    if var_start >= 0:
        var_end = header.find('$end', var_start)
        if var_end >= 0:
            line = header[var_start:var_end+4]
            print(f"  {line}")
