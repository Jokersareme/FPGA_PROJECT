#!/usr/bin/env python3
"""
Extract edge timing data from VCD waveform.
Columns:
  1. div_out_raw rising edge time (ns, 3 decimals)
  2. div_out_dtc rising edge time (ns, 3 decimals)
  3. E_combined value at div_out_raw rising edge (signed decimal)
"""

import sys

VCD_FILE = r"C:\Users\Administrator\Desktop\GS\FPGA_PROJECT\FPGA_PROJECT\RTL\testbench\workbuddy\tb_top.vcd"
OUT_CSV  = r"C:\Users\Administrator\Desktop\GS\FPGA_PROJECT\FPGA_PROJECT\RTL\testbench\workbuddy\edge_timing.csv"

# VCD identifiers (found by inspecting $var lines)
ID_DIV_RAW = "\\"      # div_out_raw
ID_DIV_DTC = "^"       # div_out_dtc (also sma_ref_p = "!", same signal)
ID_E_COMB  = "Z\""     # E_combined [10:0]  (11-bit, signed)

# E_combined declared width
# VCD says 11-bit [10:0] but RTL is [FRAC_WIDTH+1:0] = [11:0] (12-bit)
# Use RTL actual width, not VCD declared width
E_COMB_WIDTH = 12

# VCD timescale: 1ps = 1e-12 s -> ns = val / 1000.0
PS_PER_NS = 1000.0

def parse_vcd(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find start of value changes (after $dumpvars ... $end)
    dumpvars_pos = content.find('$dumpvars')
    end_pos = content.find('$end', dumpvars_pos)
    body_start = content.find('\n', end_pos) + 1
    body = content[body_start:]

    # State tracking
    curr_time = 0
    div_raw_val = '0'
    div_dtc_val = '0'
    e_comb_val = 0
    e_comb_bits = 11

    raw_rise_times = []
    dtc_rise_times = []
    # Pair: (raw_rise_time, e_comb_at_that_time)
    raw_events = []

    lines = body.split('\n')

    for line in lines:
        line = line.strip()
        if not line:
            continue

        if line.startswith('#'):
            # Time stamp
            try:
                curr_time = int(line[1:])
            except ValueError:
                pass
            continue

        # Scalar value change: b0, b1, 0, 1, x, z
        if line[0] in '01xXzZ':
            val = line[0]
            sid = line[1:]
            if sid == ID_DIV_RAW:
                if div_raw_val == '0' and val == '1':
                    raw_rise_times.append(curr_time)
                    raw_events.append((curr_time, e_comb_val))
                div_raw_val = val
            elif sid == ID_DIV_DTC:
                if div_dtc_val == '0' and val == '1':
                    dtc_rise_times.append(curr_time)
                div_dtc_val = val

        elif line[0] == 'b' or line[0] == 'B':
            # Vector value change: b<value> <id>
            parts = line[1:].split()
            if len(parts) >= 2:
                val_str = parts[0]
                sid = parts[1]
                if sid == ID_E_COMB:
                    # Parse as signed binary (two's complement)
                    # VCD omits leading zeros and may have extra bits - take low E_COMB_WIDTH bits
                    if val_str[0] == 'x' or val_str[0] == 'X' or val_str[0] == 'z' or val_str[0] == 'Z':
                        e_comb_val = 0
                    else:
                        # Take only the lowest E_COMB_WIDTH bits, then pad to full width
                        trimmed = val_str[-E_COMB_WIDTH:]
                        padded = trimmed.zfill(E_COMB_WIDTH)
                        v = int(padded, 2)
                        # Sign extend if MSB is 1
                        if padded[0] == '1':
                            v -= (1 << E_COMB_WIDTH)
                        e_comb_val = v

    return raw_events, dtc_rise_times


def main():
    print("Parsing VCD file...")
    raw_events, dtc_rise_times = parse_vcd(VCD_FILE)
    print(f"  div_out_raw rising edges: {len(raw_events)}")
    print(f"  div_out_dtc rising edges: {len(dtc_rise_times)}")

    # Match: for each raw rise, find the closest dtc rise that occurs
    # within the same period (after raw rise, before next raw rise)
    rows = []
    for i in range(len(raw_events)):
        raw_time, e_comb = raw_events[i]
        raw_time_ns = raw_time / PS_PER_NS

        # Find dtc rise in (raw_time, next_raw_time]
        next_raw_time = raw_events[i+1][0] if i+1 < len(raw_events) else raw_time + 200000
        dtc_time = None
        for dt in dtc_rise_times:
            if raw_time < dt <= next_raw_time:
                dtc_time = dt
                break

        if dtc_time is not None:
            dtc_time_ns = dtc_time / PS_PER_NS
            rows.append((raw_time_ns, dtc_time_ns, e_comb))

    print(f"  Matched pairs: {len(rows)}")

    with open(OUT_CSV, 'w', encoding='utf-8') as f:
        f.write("div_out_raw_rise_ns,div_out_dtc_rise_ns,E_combined_signed\n")
        for raw_ns, dtc_ns, e_comb in rows:
            f.write(f"{raw_ns:.3f},{dtc_ns:.3f},{e_comb}\n")

    print(f"\nWritten: {OUT_CSV}")
    print(f"  Total rows: {len(rows)}")

    # Print first 10 rows as preview
    print("\nPreview (first 10 rows):")
    print(f"{'div_out_raw_rise_ns':>20} {'div_out_dtc_rise_ns':>20} {'E_combined_signed':>18}")
    for raw_ns, dtc_ns, e_comb in rows[:10]:
        print(f"{raw_ns:20.3f} {dtc_ns:20.3f} {e_comb:18d}")


if __name__ == '__main__':
    main()
