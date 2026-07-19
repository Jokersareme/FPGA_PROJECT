// =============================================================================
// Fixed: dtc_comp.v
// Fixes applied:
//   1. dtc_load now properly driven (assign dtc_load = dtc_en)
//   2. Multiplier bit width fixed (21-bit to hold 10b x 2b x 8b = 20b max)
//   3. Saturation logic fixed (10-bit add, then saturate to 9-bit)
//   4. dtc_en now functional (gates output)
// =============================================================================

`timescale 1ns / 1ps

module dtc_comp_fixed #(
    parameter WIDTH = 10,       // e1 input width
    parameter DTC_WIDTH = 9     // dtc_code output width
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire [WIDTH-1:0]  e1,
    input  wire [7:0]        dtc_gain,
    input  wire              dtc_en,
    input  wire [DTC_WIDTH-1:0] dtc_offset,
    output wire [DTC_WIDTH-1:0] dtc_code,
    output wire              dtc_load
);

    wire dtc_code_man_en;
    wire [8:0] dtc_code_man;

    // Fixed: 10-bit e1 x 2 x 8-bit gain = max 20 bits, use 21-bit to be safe
    wire [20:0] mult;
    assign mult = e1 * 2'd2 * dtc_gain;

    // Fixed: 10-bit addition first, then saturate
    // mult[20:12] is 9-bit (matching DTC_WIDTH), dtc_offset is 9-bit
    // Sum needs 10 bits to detect overflow
    wire [8:0] mult_high = mult[20:12];
    wire [9:0] code_sum  = {1'b0, mult_high} + {1'b0, dtc_offset};

    // Fixed: saturation now works correctly (10-bit compare, 9-bit output)
    wire [DTC_WIDTH-1:0] code_sat;
    assign code_sat = (code_sum > 10'd511) ? 9'd511 : code_sum[8:0];

    // Fixed: dtc_en gating - when disabled, output midpoint (256)
    wire [DTC_WIDTH-1:0] code_active;
    assign code_active = dtc_en ? code_sat : 9'd256;

    // Final output: manual override or computed value
    assign dtc_code = dtc_code_man_en ? dtc_code_man : code_active;

    // Fixed: dtc_load is now driven
    assign dtc_load = dtc_en;

    // VIO for manual code override (debugging)
    vio_1 u_vio_dtc_comp (
        .clk           (clk),
        .probe_out0    (dtc_code_man_en),
        .probe_out1    (dtc_code_man)
    );

endmodule
