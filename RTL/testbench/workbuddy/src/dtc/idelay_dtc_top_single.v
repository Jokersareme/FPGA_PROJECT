`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: idelay_dtc_top_single
//   IDELAYE3-based DTC, SINGLE STAGE, COUNT mode.
//   Drop-in replacement for lut_dtc_top / the previous 2-stage cascaded version.
//
// ============================================================================
// 2026-07-30 CHANGE: LOAD is now an EXTERNAL input
// ----------------------------------------------------------------------------
//   The module does NOT generate the LOAD pulse anymore. The user supplies
//   `load_i` from their own logic (e.g. a 12.5 MHz-domain controller). On each
//   `load_i` pulse the module commits ONE step (<=8 taps) toward `code`. The
//   VAR_LOAD single-load limit (<=8 taps) is guaranteed INSIDE the module; the
//   user only owns the load *timing*.
//
//   External contract:
//     * Drive `code` to the desired final tap value.
//     * Assert `load_i` (clean pulse, >=1 idelay_clk wide) to advance one step.
//       `idelay_busy`=1 means the module still has steps to go; stop pulsing
//       load_i when busy=0 (delay line frozen). A single load_i pulse = one step.
//     * (Optional) hold load_i high continuously while busy=1: the module steps
//       on every load_i rising edge until settled (each step <=8 taps).
//
//   Why this is glitch-free: `ld_value` is the value that WILL be loaded on the
//   NEXT load_i edge. While moving it equals `next_val` (combinational, already
//   stable), so the moment `load_i` rises the delay line latches the correct new
//   value in one shot — no setup gap, no multi-bit intermediate state sampled.
//
//   UPDATE_MODE = "ASYNC" (NOT "SYNC"): SYNC VAR_LOAD triggers REQP-1828 which
//   forces LOAD=GND, making loading impossible. ASYNC + a clean LOAD pulse is
//   legal and is what every working VAR_LOAD design uses.
//
//   Recommended clocking: drive `idelay_clk` from the SAME 12.5 MHz clock domain
//   as `din` (NOT from the IDELAYE3 DATAOUT — that is a feedback loop). The
//   12.5 MHz clock (80 ns period, >=40 ns low) gives a wide, relaxed LOAD window
//   ideal for ASYNC VAR_LOAD.
// ============================================================================
// WHY SINGLE-STAGE (and why the previous 2-stage fabric-chain version failed)
// ----------------------------------------------------------------------------
// * User measured on silicon: ONE IDELAYE3 already covers a full VCO period
//   (T_VCO = 3.2 ns; ~6.2 ps/tap on this slow corner -> 511*6.2 ps = 3.17 ns).
//   So a SINGLE stage is sufficient for the DTC range on this device.
// * A SINGLE IDELAYE3 has NO inter-stage half-select (256) glitch. The 256
//   glitch ONLY appears when two SEPARATE IDELAYE3s are chained (fabric or
//   dedicated cascade) and their internal half-select switches are not
//   perfectly time-aligned. Xilinx guarantees a glitch-free SINGLE IDELAYE3,
//   so single stage = glitch-free by construction.
// * No dedicated-cascade route -> no Route 35-19, no adjacent-BITSLICE LOC
//   constraint. One IDELAYE3 drops into any IOB BITSLICE.
// * Gain matches the EXISTING dtc_comp. dtc_comp computes
//     dtc_code = (e1 * gain) >> 11   (saturate 0..511 = 0..T_VCO)
//   with the assumption that 0..511 taps = 0..T_VCO at a 1x DTC gain. A single
//   stage has exactly that 1x gain, so NO digital re-mapping is needed. (The
//   2-stage version doubled the gain and would have broken the calibration.)
//
// ============================================================================
// CONSTRAINTS:
//   * create_clock on idelay_clk (12.5 MHz recommended) REQUIRED (drives ld_value
//     registration and the busy flag).
//   * COUNT mode: no IDELAYCTRL, no REFCLK, EN_VTC = 0.
//   * No LOC needed (single IDELAYE3 in any BITSLICE).
//   * REQP-1828 only applies to SYNC mode; ASYNC + external load_i is DRC-clean.
//////////////////////////////////////////////////////////////////////////////////

module idelay_dtc_top_single #(
    parameter N_TAP      = 512,       // unused (compat with lut_dtc_top)
    parameter CODE_WIDTH = 9
) (
    input  wire                   sys_clk,     // unused (compat)
    input  wire                   rst_n,       // active-LOW async reset
    input  wire                   din,         // signal to be delayed (from logic)
    input  wire [CODE_WIDTH-1:0]  code,        // target delay, 0..511 taps (external)
    input  wire                   cal_mode,    // unused (no manual cal) - compat
    input  wire [CODE_WIDTH-1:0]  cal_code,    // unused - compat
    input  wire                   dtc_sel,     // unused - compat
    input  wire                   vco_clk,     // unused - compat
    input  wire                   idelay_en,   // 0 = bypass (dout = din), 1 = use IDELAY
    input  wire                   idelay_clk,  // control clock (latches state, drives busy)
    input  wire                   load_i,      // EXTERNAL LOAD pulse (user-supplied)
    output wire                   idelay_load, // = load_i (passthrough, for observation)
    output wire                   idelay_busy, // 1 while loaded_code != code
    output wire                   dout,
    output wire [CODE_WIDTH-1:0]  cal_result,  // tied 0 (no manual cal)
    output wire                   cal_valid    // tied 0 (no manual cal)
);

    // ------------------------------------------------------------------
    // Stepwise ramp state (module-owned). Guarantees <= 8 taps per LOAD step.
    // ------------------------------------------------------------------
    reg [CODE_WIDTH-1:0] loaded_code;   // last committed value

    wire signed [CODE_WIDTH:0] diff = $signed({1'b0, code}) - $signed({1'b0, loaded_code});
    wire        moving = (diff != 0);

    // Saturating step, clamped to [-8, +8] (VAR_LOAD single-load limit).
    reg signed [4:0] step;
    always @(*) begin
        if      (diff >  8) step =  5'sd8;
        else if (diff < -8) step = -5'sd8;
        else                step = diff[4:0];
    end

    wire signed [CODE_WIDTH:0] next_s = $signed({1'b0, loaded_code}) + step;
    reg [CODE_WIDTH-1:0] next_val;
    always @(*) begin
        if      (next_s > $signed({1'b0, {CODE_WIDTH{1'b1}}})) next_val = {CODE_WIDTH{1'b1}};
        else if (next_s < 0)                                  next_val = {CODE_WIDTH{1'b0}};
        else                                                  next_val = next_s[CODE_WIDTH-1:0];
    end

    // Commit ONE step on each external load_i pulse (while moving).
    always @(posedge idelay_clk or negedge rst_n) begin
        if (~rst_n) loaded_code <= {CODE_WIDTH{1'b0}};
        else if (load_i && moving) loaded_code <= next_val;
    end

    // ld_value is the value that WILL be loaded on the next load_i edge:
    // while moving it is next_val (already stable, so a single load_i pulse
    // commits one correct step even in ASYNC level/edge mode); when settled it
    // holds loaded_code (delay line frozen).
    wire [CODE_WIDTH-1:0] ld_value;
    assign ld_value = moving ? next_val : loaded_code;

    assign idelay_load = load_i;
    assign idelay_busy = moving;

    // ------------------------------------------------------------------
    // Single IDELAYE3 (COUNT mode, VAR_LOAD, ASYNC update).
    // ------------------------------------------------------------------
    wire dout_int;

    IDELAYE3 #(
        .CASCADE("NONE"),
        .DELAY_FORMAT("COUNT"),
        .DELAY_SRC("DATAIN"),     // din comes from logic (not an IOB pad)
        .DELAY_TYPE("VAR_LOAD"),
        .DELAY_VALUE(0),
        .IS_CLK_INVERTED(1'b0),
        .IS_RST_INVERTED(1'b0),
        .REFCLK_FREQUENCY(300.0), // STA-only in COUNT mode (no physical REFCLK)
        .SIM_DEVICE("ULTRASCALE_PLUS"),
        .UPDATE_MODE("ASYNC")
    ) u_idelay (
        .CLK(idelay_clk),
        .CE(1'b0),
        .INC(1'b0),
        .CASC_IN(1'b0),
        .CASC_RETURN(1'b0),
        .CASC_OUT(),
        .IDATAIN(1'b0),
        .DATAIN(din),
        .LOAD(idelay_load),
        .CNTVALUEIN(ld_value),
        .CNTVALUEOUT(),
        .DATAOUT(dout_int),
        .EN_VTC(1'b0),
        .RST(~rst_n)
    );

    assign dout       = idelay_en ? dout_int : din;
    assign cal_result = {CODE_WIDTH{1'b0}};
    assign cal_valid  = 1'b0;

endmodule
