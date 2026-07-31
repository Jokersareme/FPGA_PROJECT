# Debug VCD - find Fout & ideal_clk entries in last 80us
import re

vcd = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"
with open(vcd, 'rb') as f:
    txt = f.read().decode('latin-1')

body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]
entries = re.findall(r'#(\d+)\s*(.*?)(?=#|\Z)', body, re.DOTALL)

max_time = int(entries[-1][0])
start_time = max_time - 80000000

print(f"Searching from {start_time/1e6:.1f}us to {max_time/1e6:.1f}us")
print(f"Total entries to scan: {len(entries)}")

# Find entries with '&' or 'Q' in last 80us
found = 0
for t_str, vals in entries:
    t = int(t_str)
    if t < start_time:
        continue
    if '&' in vals or 'Q' in vals or 'R"' in vals:
        if found < 30:
            # Show context around these IDs
            for id_str in ['&', 'Q', 'R"']:
                if id_str in vals:
                    idx = vals.index(id_str)
                    ctx = vals[max(0,idx-5):idx+len(id_str)+3]
                    print(f"  T={t/1000:.3f}us: ...{repr(ctx)}...")
            found += 1
    if found >= 30:
        break

print(f"\nTotal matches in last 80us: {found}")
