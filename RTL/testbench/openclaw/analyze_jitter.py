import csv, statistics

rows = []
with open('mash_export_v4.csv') as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

raw_delays = [int(r['div_out_raw_ps']) - int(r['ideal_clk_ps']) for r in rows]
dtc_delays = [int(r['div_out_dtc_ps']) - int(r['ideal_clk_ps']) for r in rows]

print('=== Delay from ideal clock edge (ps) ===')
print('  row   raw_delay  dtc_delay')
for i in range(min(12, len(rows))):
    print(f'  row[{i:3d}]  {raw_delays[i]:10d}  {dtc_delays[i]:10d}')
print('  ...')

print(f'\nRaw delay:  mean={statistics.mean(raw_delays):>8.1f} ps  stdev={statistics.stdev(raw_delays):>8.1f} ps  pkpk={max(raw_delays)-min(raw_delays)} ps')
print(f'DTC delay:  mean={statistics.mean(dtc_delays):>8.1f} ps  stdev={statistics.stdev(dtc_delays):>8.1f} ps  pkpk={max(dtc_delays)-min(dtc_delays)} ps')

ideal_ps = [int(r['ideal_clk_ps']) for r in rows]
ideal_periods = [ideal_ps[i+1] - ideal_ps[i] for i in range(len(ideal_ps)-1)]
ideal_mean = statistics.mean(ideal_periods)

raw_ps = [int(r['div_out_raw_ps']) for r in rows]
raw_periods = [raw_ps[i+1] - raw_ps[i] for i in range(len(raw_ps)-1)]

dtc_ps = [int(r['div_out_dtc_ps']) for r in rows]
dtc_periods = [dtc_ps[i+1] - dtc_ps[i] for i in range(len(dtc_ps)-1)]

raw_jitter = [p - ideal_mean for p in raw_periods]
dtc_jitter = [p - ideal_mean for p in dtc_periods]

print(f'\n=== Period Jitter ===')
print(f'Ideal clock: mean period = {ideal_mean/1000:.3f} ns (= {int(1e6/(ideal_mean/1000))} kHz)')
print(f'\nRaw clock period jitter:')
print(f'  Stdev: {statistics.stdev(raw_jitter):>8.1f} ps')
print(f'  PkPk: {max(raw_jitter)-min(raw_jitter)} ps')
print(f'  Range: {min(raw_jitter):>+8.1f} ~ {max(raw_jitter):>+8.1f} ps')
print(f'\nDTC clock period jitter:')
print(f'  Stdev: {statistics.stdev(dtc_jitter):>8.1f} ps')
print(f'  PkPk: {max(dtc_jitter)-min(dtc_jitter)} ps')
print(f'  Range: {min(dtc_jitter):>+8.1f} ~ {max(dtc_jitter):>+8.1f} ps')
