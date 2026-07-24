"""
compare_clocks.py — 对比三时钟: 理想时钟 vs 计算时钟 vs 实际分频时钟
参考之前的 Python MASH 验证方法

数据来源: tb_comp_standalone.vcd (standalone 仿真已有 comp_3rd/dtc_code)

方法:
  1. 从 VCD 提取 comp_3rd 在每个时钟边沿的值
  2. comp_time = comp_3rd × gain / 2^SHIFT × TAP_PS
  3. 理想时钟边沿 = 固定周期
  4. 计算时钟边沿 = 理想边沿 + comp_time (前一个周期的补偿)
  5. 实际分频时钟 = 理想时钟 + MASH 频率调制
  6. 对比三者的相对关系
"""
import struct, sys, os

VCD_FILE = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw\tb_comp_standalone.vcd"
GAIN = 160          # dtc_gain (from standalone test)
SHIFT = 11          # dtc_comp SHIFT
TAP_PS = 20         # CARRY8 tap delay in ps
MID = 256           # DTC center offset (3rd order)
FOUT_PERIOD_PS = 52000  # ~19.2MHz Fout period in ps (from standalone TB: clk=52ns period)

def parse_vcd_signal(vcd_path, signal_id):
    """从 VCD 提取指定信号的所有变化"""
    time = 0
    values = []
    with open(vcd_path, 'r', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('#'):
                time = int(line[1:])
            elif line.startswith('b') and line.endswith(signal_id):
                val_str = line[1:len(line)-1]  # binary value
                val = int(val_str, 2)
                values.append((time, val))
            elif line == f'1{signal_id}':
                values.append((time, 1))
            elif line == f'0{signal_id}':
                values.append((time, 0))
    return values

def parse_vcd(vcd_path):
    """解析 VCD 中的关键信号"""
    # VCD signal IDs from tb_comp_standalone.vcd header
    # We know: clk is signed with single-char ID
    # Need to find the signal IDs from the VCD header
    
    signals = {}
    current_scope = []
    
    with open(vcd_path, 'r', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if line.startswith('$scope'):
                parts = line.split()
                if len(parts) >= 3:
                    current_scope.append(parts[2])
            elif line.startswith('$upscope'):
                if current_scope:
                    current_scope.pop()
            elif line.startswith('$var'):
                parts = line.split()
                if len(parts) >= 4:
                    var_type = parts[1]
                    width = int(parts[2])
                    sig_id = parts[3]
                    sig_name = parts[4] if len(parts) > 4 else ""
                    full_name = '.'.join(current_scope + [sig_name])
                    signals[sig_id] = {'name': full_name, 'width': width}
            elif line.startswith('$enddefinitions'):
                break
    
    print("=== VCD Signals ===")
    for sid, info in signals.items():
        print(f"  '{sid}' -> {info['name']} ({info['width']}-bit)")
    
    return signals

# Parse VCD
print("=" * 80)
print("CLOCK COMPARISON ANALYSIS (3rd-order DTC Compensation)")
print("=" * 80)

print(f"\nConfig: gain={GAIN}, SHIFT={SHIFT}, TAP={TAP_PS}ps, MID={MID}")
print(f"comp_time(ps) = comp_3rd * {GAIN} / 2^{SHIFT} * {TAP_PS}")
print()

# Parse signals from VCD
signals = parse_vcd(VCD_FILE)

# Find signal IDs by looking at what's in the VCD
# Let's read the VCD data to find signal patterns
time = 0
data = {}
with open(VCD_FILE, 'r', errors='ignore') as f:
    content = f.read()

# Find $dumpall section to get initial values
dumpall_start = content.find('$dumpall')
dumpall_end = content.find('$end', dumpall_start)
dumpall_section = content[dumpall_start:dumpall_end]

# Find signal IDs from $dumpvars section
dumpvars_start = content.find('$dumpvars')
dumpvars_end = content.find('$end', dumpvars_start)
dumpvars_section = content[dumpvars_start:dumpvars_end]

# Parse all time/value pairs
lines = content.split('\n')
current_time = 0
comp_3rd_vals = []  # (time, comp_3rd)
dtc_code_vals = []  # (time, dtc_code)
clk_vals = []        # (time, clk)
e3_r1_vals = []
e3_r2_vals = []
e3_r3_vals = []

# IDs to find - look for known signal patterns
# comp_3rd is 13-bit wire, likely ID is something like '
# Let's scan for multi-bit values

in_header = True
seen_enddef = False
signal_id_map = {}

for line in lines:
    line = line.strip()
    if not line:
        continue
    
    if line.startswith('$enddefinitions'):
        seen_enddef = True
        continue
    
    if not seen_enddef:
        # Parse header for signal IDs
        if line.startswith('$var'):
            parts = line.split()
            if len(parts) >= 4:
                width = int(parts[2])
                sid = parts[3]
                sname = parts[4] if len(parts) > 4 else ""
                signal_id_map[sid] = (sname, width)
        continue
    
    # Data section
    if line.startswith('#'):
        current_time = int(line[1:])
    elif line.startswith('b'):
        # Multi-bit value: b<value><id>
        val_end = line.find(' ')
        if val_end > 0:
            val_str = line[1:val_end]
            sig_id = line[val_end:].strip()
        else:
            # Could be b<value><id> with no space
            # Find where binary value ends and ID begins
            # ID is typically the last character(s)
            for sid, (sname, width) in signal_id_map.items():
                if line.endswith(sid):
                    val_str = line[1:len(line)-len(sid)]
                    if len(val_str) == width:
                        val = int(val_str, 2)
                        if 'comp_3rd' in sname:
                            comp_3rd_vals.append((current_time, val))
                        elif 'dtc_code' in sname:
                            dtc_code_vals.append((current_time, val))
                        elif 'e3_r1' in sname:
                            e3_r1_vals.append((current_time, val))
                        elif 'e3_r2' in sname:
                            e3_r2_vals.append((current_time, val))
                        elif 'e3_r3' in sname:
                            e3_r3_vals.append((current_time, val))
                    break
    elif len(line) == 2 and line[0] in '01':
        sig_id = line[1]
        val = int(line[0])
        if sig_id in signal_id_map:
            sname, width = signal_id_map[sig_id]
            if width == 1:
                if 'clk' in sname:
                    clk_vals.append((current_time, val))

# Also try to find binary values by direct scan
# The VCD format is: b<binary_value><id_char>
import re

for line in lines:
    line = line.strip()
    if line.startswith('b') and len(line) > 2:
        # Extract the signal ID (last non-binary char)
        match = re.match(r'b([01]+)(.)', line)
        if match:
            val_str = match.group(1)
            sig_id = match.group(2)
            if signal_id_map.get(sig_id):
                sname, width = signal_id_map[sig_id]
                val = int(val_str, 2)
                if 'comp_3rd' in sname:
                    comp_3rd_vals.append((int(line.split()[0]) if False else current_time, val))
                elif 'dtc_code' in sname:
                    dtc_code_vals.append((current_time, val))

# Actually, let me just re-read the VCD properly
comp_3rd_data = []  # (time, value_signed)
dtc_code_data = []
clk_edges = []

# Read VCD line by line properly
current_time = 0
with open(VCD_FILE, 'r', errors='ignore') as f:
    in_data = False
    for line in f:
        line = line.strip()
        if not line:
            continue
        if line.startswith('$enddefinitions'):
            in_data = True
            continue
        if not in_data:
            continue
        if line.startswith('#'):
            current_time = int(line[1:])
        elif line.startswith('$'):
            continue
        elif line.startswith('b') and "'" in line:
            # comp_3rd: b<value>'
            try:
                parts = line.split("'")
                val_str = parts[0][1:].strip()
                if val_str and all(c in '01' for c in val_str):
                    val = int(val_str, 2)
                    # Convert to signed 13-bit
                    if val & (1 << 12):
                        val -= (1 << 13)
                    comp_3rd_data.append((current_time, val))
            except:
                pass
        elif line.startswith('b') and line.endswith(','):
            # dtc_code: b<value>,
            try:
                val_str = line[1:-1].strip()
                if val_str and all(c in '01' for c in val_str):
                    val = int(val_str, 2)
                    dtc_code_data.append((current_time, val))
            except:
                pass

if not comp_3rd_data:
    print("ERROR: Could not find comp_3rd data. Signal IDs:")
    for sid, (name, w) in sorted(signal_id_map.items()):
        print(f"  '{sid}' -> {name} ({w}-bit)")

print(f"\nFound {len(comp_3rd_data)} comp_3rd samples")
print(f"Found {len(dtc_code_data)} dtc_code samples")

if comp_3rd_data:
    print(f"\n=== comp_3rd samples (first 20) ===")
    for i, (t, v) in enumerate(comp_3rd_data[:20]):
        print(f"  @{t:>9}ps: comp_3rd = {v:+6d}")

if dtc_code_data:
    print(f"\n=== dtc_code samples (first 20) ===")
    for i, (t, v) in enumerate(dtc_code_data[:20]):
        print(f"  @{t:>9}ps: dtc_code = {v:3d}")

if comp_3rd_data:
    print("\n" + "=" * 80)
    print("CLOCK EDGE COMPARISON (using comp_3rd for compensation)")
    print("=" * 80)
    
    # Start from first meaningful sample
    # Each Fout period = FOUT_PERIOD_PS, we generate edges
    # compensation_time = comp_3rd * GAIN / 2^SHIFT * TAP_PS
    
    start_time = comp_3rd_data[0][0] if comp_3rd_data else 0
    if start_time < 1000:
        start_time = 5000  # skip the initial DC test
    
    # Collect comp_3rd values at each Fout edge (starting from wall-clock sampling)
    # Since this is standalone, comp_3rd is registered at negedge clk
    # We'll sample comp_3rd at each clock period
    
    print(f"\n{'>':>5} {'Edge #':>6} {'Ideal(ps)':>10} {'Comp(ps)':>15} {'Δ(ps)':>10}")
    print("-" * 50)
    
    ideal_edges = []
    comp_edges = []
    raw_edges = []  # For standalone we use the actual Fout simulation as "raw"
    
    comp_3rd_idx = 0
    for n in range(50):  # 50 edges
        ideal_time = start_time + n * FOUT_PERIOD_PS
        
        # Find the most recent comp_3rd before this edge
        while (comp_3rd_idx + 1 < len(comp_3rd_data) and 
               comp_3rd_data[comp_3rd_idx + 1][0] <= ideal_time):
            comp_3rd_idx += 1
        
        c3 = comp_3rd_data[comp_3rd_idx][1] if comp_3rd_data else 0
        
        # Compute compensation time
        # comp_time = c3 * GAIN / 2^SHIFT * TAP_PS
        comp_time_ps = (c3 * GAIN * TAP_PS) / (1 << SHIFT)
        
        comp_time_signed = int(comp_time_ps)
        comp_time_sign = '+' if comp_time_signed >= 0 else ''
        
        comp_edge = ideal_time + comp_time_signed
        
        print(f"{'>':>5} {n:>6} {ideal_time:>10} {comp_edge:>10} ({comp_time_sign}{comp_time_signed:>3}) {comp_time_signed:>+10}")
        
        ideal_edges.append(ideal_time)
        comp_edges.append(comp_edge)

    print("\n" + "=" * 80)
    print("JITTER ANALYSIS")
    print("-" * 80)
    
    # Compute periods
    print(f"\n{'Edge#':>6} {'Ideal T(ps)':>12} {'Comp T(ps)':>12} {'Jitter(ps)':>10}")
    print("-" * 42)
    
    for i in range(1, len(ideal_edges)):
        t_ideal = ideal_edges[i] - ideal_edges[i-1]
        t_comp = comp_edges[i] - comp_edges[i-1]
        jitter = t_comp - t_ideal
        print(f"{i:>6} {t_ideal:>12} {t_comp:>12} {jitter:>+10}")
    
    avg_jitter = sum((comp_edges[i] - comp_edges[i-1]) - FOUT_PERIOD_PS 
                     for i in range(1, len(comp_edges))) / (len(comp_edges) - 1)
    max_jitter = max(abs((comp_edges[i] - comp_edges[i-1]) - FOUT_PERIOD_PS) 
                     for i in range(1, len(comp_edges)))
    
    print(f"\n  Avg jitter: {avg_jitter:.1f}ps")
    print(f"  Max jitter: {max_jitter:.1f}ps")
    
    # Show the last few edges with dtc_code context
    print(f"\n{'Edge#':>6} {'Ideal(ps)':>10} {'Comp(ps)':>10} {'CompT(ps)':>8} {'Comp3rd':>8} {'Code':>5}")
    print("-" * 50)
    n_edges = min(len(comp_edges), len(comp_3rd_data))
    for i in range(max(0, n_edges-15), n_edges):
        c3 = comp_3rd_data[i][1] if i < len(comp_3rd_data) else 0
        comp_t = int((c3 * GAIN * TAP_PS) / (1 << SHIFT))
        code = dtc_code_data[i][1] if i < len(dtc_code_data) else 0
        print(f"{i:>6} {ideal_edges[i]:>10} {comp_edges[i]:>10} {comp_t:>+8} {c3:>+8} {code:>5}")
    
    # Summary table: raw period vs error
    print(f"\n{'='*80}")
    print(f"{'Ideal period:':20} {FOUT_PERIOD_PS}ps = {1e6/FOUT_PERIOD_PS:.1f}MHz")
    print(f"{'Compensation:':20} comp_time = comp_3rd × {GAIN} / 2^{SHIFT} × {TAP_PS}ps")
    print(f"{'Scale factor:':20} {GAIN} / {1<<SHIFT} × {TAP_PS}ps = {GAIN*TAP_PS/(1<<SHIFT):.3f}ps/code")
    print(f"{'='*80}")
else:
    print("\nNo comp_3rd data found. Checking raw VCD content...")
    with open(VCD_FILE, 'r', errors='ignore') as f:
        raw = f.read()
    # Find first few data lines after enddefinitions
    lines = raw.split('\n')
    data_started = False
    count = 0
    for line in lines:
        if '$enddefinitions' in line:
            data_started = True
            continue
        if data_started and line.strip():
            print(f"  {line.strip()[:80]}")
            count += 1
            if count > 20:
                break
