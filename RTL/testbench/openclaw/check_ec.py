# Check E_combined in VCD
with open(r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd", 'rb') as f:
    d = f.read()
t = d.decode('latin-1')

# Find body start
body_start = t.find('$dumpvars')
end_idx = t.find('$end', body_start)
body = t[end_idx+4:]

# Count R" occurrences
cnt = body.count('R"')
print(f'R" (E_combined) occurs {cnt} times in VCD body')

# Show first 10 with context
import re
for m in re.finditer(r'.{0,40}R".{0,5}', body):
    print(f'  offset {m.start()}: ...{repr(m.group())}...')

# Also check the variable header for full path
header = t[:body_start]
for m in re.finditer(r'\$var.*?R".*?\$end', header):
    print(f"\nHeader: {m.group()}")
