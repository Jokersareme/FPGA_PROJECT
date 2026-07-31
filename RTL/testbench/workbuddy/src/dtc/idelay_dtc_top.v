`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: idelay_dtc_top  (IDELAYE3-based DTC, NO manual calibration, COUNT mode)
//
// Drop-in alternative to lut_dtc_top: the delay line is built from cascaded
// IDELAYE3 primitives instead of the CARRY8 carry-chain. Port list and
// parameter list are identical to lut_dtc_top, so it can replace it directly
// in the parent (dtc_cal_top / pll_top).
//
// ============================================================================
// IMPORTANT - COUNT MODE, NO IDELAYCTRL, NO REFCLK DEPENDENCE
// ----------------------------------------------------------------------------
// This module uses DELAY_FORMAT="COUNT" + DELAY_TYPE="VAR_LOAD". In COUNT mode:
//   * The per-tap delay is a FIXED process value (~2.5-15 ps, typical ~5 ps)
//     that varies with PVT but is INDEPENDENT of any reference clock.
//     (Ref: AMD Answer 66013 - UltraScale IDELAY/ODELAY resolution is over PVT,
//      NOT dependent on the IDELAYCTRL REFCLK. Only 7-series IDELAYE2 was
//      REFCLK-dependent. So 125 MHz vs 300 MHz gives the SAME per-tap delay.)
//   * No IDELAYCTRL is required (Answer 66013: "not required if used in COUNT
//     mode") and EN_VTC is tied 0. The 125 MHz clock is used ONLY as the
//     IDELAYE3 control clock (idelay_clk); it does NOT set the delay.
//   * REFCLK_FREQUENCY below is therefore STA-only (timing-analysis nominal);
//     there is no physical REFCLK. It is kept at 300.0 (within 200-800 MHz) so
//     Vivado's static timing analysis stays clean.
//
// ============================================================================
// WHAT CHANGED vs CARRY8 version:
// ----------------------------------------------------------------------------
// 1) NO MANUAL CALIBRATION.
//    The per-stage calibration IDELAYE3 chain + TDC is REMOVED. IDELAYE3 is a
//    dedicated, matched, characterized tapped delay line whose INL is only a few
//    ps, so no INL LUT / endpoint calibration is needed. The existing sign-sign
//    LMS loop in dtc_cal_top still auto-estimates the average ps/code gain.
//    cal_result / cal_valid are tied to 0 purely to keep the port list identical.
//
// 2) CHAINED IDELAYE3, NO OUTPUT MUX, NO DEDICATED CASCADE ROUTING.
//    ALL MAIN_STAGES IDELAYE3 are ALWAYS in the signal path. Each stage is
//    loaded with the same `code`. The delayed output (DATAOUT) of one stage feeds
//    the data input (DATAIN) of the next stage. CASCADE="NONE" is used on every
//    stage -> the fragile dedicated IDELAYE3 CASC routing (which only exists
//    between strictly adjacent BITSLICE sites and caused Route 35-19 placement
//    failures) is NOT used. Stages only need to be in the SAME IO bank; no
//    adjacent-bitslice placement constraint.
//    (See linearity note below.)
//
// 3) RANGE  (REFCLK-independent; nominal numbers below).
//    A single IDELAYE3 has 512 taps. Per-tap ~2.5-15 ps (PVT), nominal ~2.5 ps
//    -> single-stage max ~1.28 ns (511 taps). This is the SAME at any REFCLK.
//    MAIN_STAGES = 4  ->  max ~ 5.1 ns  >=  3.2 ns requirement  (~1.9 ns margin).
//    Why 4 and not 2: in COUNT mode there is NO calibration, so at the WORST-CASE
//    PVT corner (tap = 2.5 ps) the range shrinks. 2 stages -> 2.56 ns < 3.2 ns
//    (FAILS); 3 stages -> 3.84 ns (minimum that still meets 3.2 ns); 4 stages
//    gives extra margin. Keep MAIN_STAGES = 4 unless you add IDELAYCTRL (TIME
//    mode) for calibration, in which case 2 stages may suffice.
//    NOTE: the inter-stage DATAOUT->DATAIN fabric hop adds a small (~0.1-0.3 ns)
//    constant delay per stage; it reduces the effective range marginally but
//    well within the 3.2 ns budget.
//
// ============================================================================
// LINEARITY NOTE (why no stage-count MUX):
// ----------------------------------------------------------------------------
// Selecting 1-vs-4 stages with a MUX (different # of IDELAYs per delay value)
// HURTS linearity:
//   (a) the fabric MUX adds a path-dependent parasitic delay that is NOT part of
//       the matched delay line and drifts with PVT;
//   (b) there is a kink / offset discontinuity at the MUX selection boundary,
//       breaking monotonic INL.
// With DATAOUT->DATAIN chaining (no MUX), the per-stage delay is set only by
// `code` on a matched IDELAYE3 line; the only extra delay between stages is a
// single fixed fabric net (identical for ALL codes), which adds a CONSTANT
// offset -> NOT code-dependent -> no INL. Tuning law stays uniform and matched.
// (idelay_en still selects din vs chain, but that is a DTC on/off MODE switch,
//  not part of the tuning law, so it does not degrade tuning linearity.)
//
// Effective LSB (resolution): with all stages = same code, a 1-LSB code step
// moves every stage by 1 tap, so LSB = MAIN_STAGES * (per-tap). Nominal per-tap
// ~2.5 ps -> for 4 stages ~10 ps. The per-tap itself drifts 2.5-15 ps with PVT,
// so the LSB also drifts; the LMS gain loop absorbs this (it estimates ps/code).
//
// ============================================================================
// CONSTRAINTS (read before synthesis):
//   * IDELAYE3 lives in the IO bank -> limited count per bank. This module uses
//     only MAIN_STAGES IDELAYE3 (no calibration chain). 4 stages = 4 IOBs.
//   * COUNT mode: NO IDELAYCTRL required; EN_VTC = 0. Do NOT add an IDELAYCTRL
//     here - it would be inert in COUNT mode. (If you later switch to TIME mode
//     for VT-stable delays, you WILL need a >=200 MHz IDELAYCTRL REFCLK, e.g.
//     generated by an MMCM from your 125 MHz clock.)
//   * All IDELAYE3 must be placed in the SAME IO bank. Because we chain via
//     DATAOUT->DATAIN (CASCADE="NONE"), there is NO strict adjacent-bitslice
//     requirement (unlike dedicated CASC routing). To be safe, add a Pblock /
//     LOC constraint keeping the STAGES IDELAYE3 in one bank if auto-placement
//     scatters them across banks.
//   * idelay_clk (125 MHz control clock) must be jitter-clean.
//////////////////////////////////////////////////////////////////////////////////

module idelay_dtc_top #(
    parameter N_TAP       = 512,      // unused (kept for compat with lut_dtc_top)
    parameter CODE_WIDTH  = 9,
    parameter MAIN_STAGES = 4         // cascaded IDELAYE3, ALL always active
) (
    input  wire              sys_clk,
    input  wire              rst_n,
    input  wire              din,
    input  wire [CODE_WIDTH-1:0] code,
    input  wire              cal_mode,   // unused (no calibration) - compat
    input  wire [CODE_WIDTH-1:0] cal_code, // unused - compat
    input  wire              dtc_sel,    // unused (pure cascade) - compat
    input  wire              vco_clk,    // unused (no TDC) - compat
    input  wire              idelay_en,  // 0=bypass(dout=din), 1=use IDELAY path
    input  wire              idelay_clk, // IDELAYE3 control clock (NOT a REFCLK;
                                        //   COUNT mode needs no IDELAYCTRL REFCLK)
    output wire              idelay_load,// IDELAYE3 LOAD (VAR_LOAD)
    output wire              dout,
    output wire [CODE_WIDTH-1:0] cal_result, // tied 0 (no manual calibration)
    output wire              cal_valid           // tied 0 (no manual calibration)
);

    localparam STAGES = MAIN_STAGES;

    // ------------------------------------------------------------------
    // Chained IDELAYE3 delay line (CASCADE="NONE").
    // ALL stages are ALWAYS in the path. Stage s delays its DATAIN by `code`
    // taps; its DATAOUT drives the DATAIN of stage s+1.
    // No dedicated CASC routing -> no adjacent-bitslice placement constraint
    // (stages only need to share the SAME IO bank). COUNT mode: EN_VTC=0,
    // no IDELAYCTRL, per-tap delay is REFCLK-independent.
    // ------------------------------------------------------------------
    wire [STAGES-1:0] main_do;

    // NOTE: CASCADE/DELAY_* are selected with literal strings (not a ternary
    // expression) so the module also parses under iverilog's limited string-param
    // handling. In Vivado this is equivalent to a single parameterized instance.
    genvar s;
    generate
        for (s = 0; s < STAGES; s = s + 1) begin : main_delay
            if (s == 0) begin
                IDELAYE3 #(
                    .CASCADE("NONE"), .DELAY_FORMAT("COUNT"), .DELAY_SRC("DATAIN"),
                    .DELAY_TYPE("VAR_LOAD"), .DELAY_VALUE(0), .IS_CLK_INVERTED(1'b0),
                    .IS_RST_INVERTED(1'b0), .REFCLK_FREQUENCY(300.0),
                    .SIM_DEVICE("ULTRASCALE_PLUS"), .UPDATE_MODE("ASYNC")
                ) u_idelay (
                    .CLK(idelay_clk), .CE(1'b0),
                    .CASC_IN(1'b0), .CASC_RETURN(1'b0), .CASC_OUT(),
                    .IDATAIN(1'b0), .DATAIN(din),
                    .INC(1'b0), .LOAD(idelay_load),
                    .CNTVALUEIN(code), .CNTVALUEOUT(), .DATAOUT(main_do[s]),
                    .EN_VTC(1'b0), .RST(~rst_n)
                );
            end else begin
                IDELAYE3 #(
                    .CASCADE("NONE"), .DELAY_FORMAT("COUNT"), .DELAY_SRC("DATAIN"),
                    .DELAY_TYPE("VAR_LOAD"), .DELAY_VALUE(0), .IS_CLK_INVERTED(1'b0),
                    .IS_RST_INVERTED(1'b0), .REFCLK_FREQUENCY(300.0),
                    .SIM_DEVICE("ULTRASCALE_PLUS"), .UPDATE_MODE("ASYNC")
                ) u_idelay (
                    .CLK(idelay_clk), .CE(1'b0),
                    .CASC_IN(1'b0), .CASC_RETURN(1'b0), .CASC_OUT(),
                    .IDATAIN(1'b0), .DATAIN(main_do[s-1]),
                    .INC(1'b0), .LOAD(idelay_load),
                    .CNTVALUEIN(code), .CNTVALUEOUT(), .DATAOUT(main_do[s]),
                    .EN_VTC(1'b0), .RST(~rst_n)
                );
            end
        end
    endgenerate

    // DTC on/off: idelay_en selects chain output vs raw din. This is a mode
    // switch, not part of the tuning law, so it does not degrade tuning linearity.
    assign dout = idelay_en ? main_do[STAGES-1] : din;

    // VAR_LOAD: hold LOAD high so the line continuously tracks CNTVALUEIN (=code).
    assign idelay_load = 1'b1;

    // No manual calibration: cal outputs inert (kept only for port compatibility).
    assign cal_result = {CODE_WIDTH{1'b0}};
    assign cal_valid  = 1'b0;

    // sys_clk / cal_mode / cal_code / dtc_sel / vco_clk are retained for pin
    // compatibility with lut_dtc_top; the IDELAY path does not use them.

endmodule
