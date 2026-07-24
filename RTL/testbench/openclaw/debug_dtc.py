# Debug dtc edge counting
import re
with open(r'D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd', 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Find first 20 dtc edges with context
matches = list(re.finditer(r'1\s*S', body))
print(f"Total '1S' matches: {len(matches)}")
print(f"\nFirst 20 matches with time context:")
for i, m in enumerate(matches[:20]):
    start = max(0, m.start()-30)
    end = min(len(body), m.end()+5)
    ctx = body[start:end].replace('\r','').replace('\n',' ')
    # Find the #time before this match
    before = body[:m.start()]
    times = list(re.finditer(r'#(\d+)', before))
    t = times[-1].group(1) if times else '?'
    s = m.start()
    print(f"  match {i}: T={t}ps at offset {s}: ...{ctx}...")
