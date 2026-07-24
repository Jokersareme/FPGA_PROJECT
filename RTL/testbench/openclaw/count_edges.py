# Count dtc edges with raw grep
import re
with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    data = f.read()
txt = data.decode('latin-1')
body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Count all occurrences of 1S (dtc rising) and 0S (dtc falling)
rising = len(re.findall(r'1\s*S', body))
falling = len(re.findall(r'0\s*S', body))
print(f'dtc rising: {rising}, falling: {falling}')

# Also count raw edges
raw_rising = len(re.findall(r'1\s*Q', body))
raw_falling = len(re.findall(r'0\s*Q', body))
print(f'raw rising: {raw_rising}, falling: {raw_falling}')

# Check for 'i$' (carry_dout) edges too
carry_rising = len(re.findall(r'1\s+i\$', body))
carry_falling = len(re.findall(r'0\s+i\$', body))
print(f'carry_dout rising: {carry_rising}, falling: {carry_falling}')
