# Export waveform data to CSV
import re, csv

vcd = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_quick_3rd.vcd"
csv_path = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\waveform_export.csv"

with open(vcd, 'rb') as f:
    data = f.read()
txt = data.decode('latin-1')

# Variable map
scope_stack = ['']
var_map = {}
for m in re.finditer(r'\$scope (\w+) (\S+)|\$upscope|'
                     r'\$var (\w+) (\d+) (\S+) (\S+)', txt[:txt.find('$dumpvars')]):
    if m.group(1):
        scope_stack.append(m.group(2))
    elif m.group(0) == '$upscope':
        if len(scope_stack) > 1: scope_stack.pop()
    elif m.group(3):
        _, w, idc, nm = m.group(3), m.group(4), m.group(5), m.group(6)
        full = '.'.join(scope_stack[1:] + [nm])
        var_map[idc] = (nm, full, int(w))

# Target signals: ideal_clk (&), Fout=div_out_raw(Q), E_combined(R")
# Also add: sys_rst, cal_done, dtc_code, state, dtc_gain_cal
sig_ids = {
    'ideal_clk': '&',
    'div_out_raw': 'Q',      # u_sys_bufg_fracn_out.I
    'E_combined': 'R"',      # u_fracn_div.E_combined
}

# Parse body into time-value pairs
body_start = txt.find('$end', txt.find('$dumpvars')) + 4
body = txt[body_start:]

# Build current value tracker
current = {name: None for name in sig_ids}
timestamps = []
rows = []
prev_time = 0

# Parse line by line
for line in body.split('\n'):
    line = line.strip()
    if not line:
        continue
    if line.startswith('#'):
        prev_time = int(line[1:])
        continue
    
    # Check each signal
    for name, idc in sig_ids.items():
        if len(idc) == 1:
            # Single char ID: value can be 0/1/x/z followed by whitespace and ID
            m = re.match(r'^([01xzXZ])\s+' + re.escape(idc) + r'\s*$', line)
            if m:
                val = m.group(1)
                if val != current[name]:
                    # Record change
                    current[name] = val
                    timestamps.append((prev_time, name, val))
        else:
            # Multi-char ID: handle differently
            # For E_combined (R" = 2 chars), try regex
            m = re.match(r'^b([01xzXZ]+)\s+' + re.escape(idc) + r'\s*$', line)
            if m:
                val = m.group(1)
                if val != current[name]:
                    current[name] = val
                    timestamps.append((prev_time, name, val))
            else:
                # Also try scalar format
                m = re.match(r'^([01xzXZ])\s+' + re.escape(idc) + r'\s*$', line)
                if m:
                    val = m.group(1)
                    if val != current[name]:
                        current[name] = val
                        timestamps.append((prev_time, name, val))

# Group by time and produce CSV
from collections import defaultdict

time_rows = defaultdict(dict)
for t, name, val in timestamps:
    time_rows[t][name] = val

# Add all initial values
time_rows[0] = {}
for name in sig_ids:
    time_rows[0][name] = current.get(name, 'x')

# Sample on Fout rising edges only
# Also include all time points where E_combined or ideal_clk changes
sorted_times = sorted(time_rows.keys())
last_fout = None

samples = []
for t in sorted_times:
    row = time_rows[t]
    fout_val = row.get('div_out_raw', 'x')
    is_rise = (fout_val == '1' and last_fout != '1')
    last_fout = fout_val
    
    # Record: include all times for completeness
    samples.append((t, row))

# Write CSV
with open(csv_path, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['time_ps', 'time_us', 'ideal_clk', 'div_out_raw', 'E_combined'])
    
    for t, row in samples:
        clk = row.get('ideal_clk', 'x')
        fout = row.get('div_out_raw', 'x')
        ec = row.get('E_combined', 'x')
        # Convert E_combined from binary to integer if it's a binary string
        if len(ec) > 1:
            try:
                ec_int = int(ec, 2)
                # Sign-extend for 13-bit signed
                if ec_int >= 0x1000:
                    ec_int -= 0x2000
                ec = str(ec_int)
            except:
                pass
        writer.writerow([t, t/1000, clk, fout, ec])

print(f"Written {len(samples)} rows to {csv_path}")
print(f"File size: {os.path.getsize(csv_path) / 1024:.0f} KB" if os.path.exists(csv_path) else "File not found!")
