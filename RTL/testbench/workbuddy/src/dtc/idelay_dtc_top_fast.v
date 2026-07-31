`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: idelay_dtc_top_fast  (IDELAYE3 DTC, FAST + LARGE-JUMP optimized)
// Drop-in alternative to lut_dtc_top / idelay_dtc_top.
//
// DESIGN GOAL: fast settling + large code jumps, glitch-free to the PLL.
//
// HOW THIS MEETS "FAST + LARGE JUMP" (Xilinx AR#66013 / AR#67246 / UG861):
//   * VAR_LOAD hard limit: a SINGLE load may change the delay by at most 8
//     taps, or the line glitches (AR#66013: "maximum adjustment of 8 taps
//     only is permitted or the signal could glitch"). This is a PER-LOAD
//     limit, NOT a time limit -> the solution is NOT "wait", it is "step
//     every clock by <=8 taps".
//   * AR#66013 also says CNTVALUEIN adjustments are possible EVERY clock
//     cycle, and the new value takes effect the next clock cycle. So we
//     pipeline: one 8-tap step per idelay_clk, back-to-back, no inter-step
//     wait. (The 10/5-clock waits in AR#67246/UG861 are for toggling EN_VTC
//     for VT tracking -- we keep EN_VTC=0 / COUNT mode, so they do NOT apply.)
//   * FULL-RANGE (511 taps) @ 125 MHz idelay_clk = 64 steps * 8 ns = 512 ns.
//     @ 250 MHz = 256 ns. Fast enough for any PLL calibration loop.
//   * GATING DURING JUMP (AR#67246 "gate the clock during large adjustment",
//     adapted to component mode): the output MUX selects the delayed path
//     ONLY when `!busy` (settled). While ramping, dout = din (bypass), so the
//     64 intermediate steps never reach the PLL as glitches. This is the
//     component-mode equivalent of TBYTE_IN/TX_GATING.
//
// IMPORTANT: drive idelay_clk with a FAST clock (sys_clk, 125 MHz+).
//   idelay_clk is the LOADER clock, NOT the 12.5 MHz DTC output clock.
//   The 12.5 MHz DTC output is what flows through `din` -> delayed -> dout.
//
// MODE: UPDATE_MODE="ASYNC" + EN_VTC=0 + DELAY_FORMAT="COUNT" (no IDELAYCTRL).
//   ASYNC is required because SYNC forces LOAD=GND (REQP-1828) which cannot
//   load at all. ASYNC + LOAD pulse is legal and required.
//////////////////////////////////////////////////////////////////////////////////

module idelay_dtc_top_fast #(
    parameter N_TAP       = 512,
    parameter CODE_WIDTH  = 9,
    parameter MAIN_STAGES = 2,
    parameter MAX_STEP    = 8      // Xilinx hard limit: <=8 taps/load
) (
    input  wire              sys_clk,
    input  wire              rst_n,
    input  wire              din,
    input  wire [CODE_WIDTH-1:0] code,
    input  wire              cal_mode,
    input  wire [CODE_WIDTH-1:0] cal_code,
    input  wire              dtc_sel,
    input  wire              vco_clk,
    input  wire              idelay_en,    // 1=use delayed path, 0=bypass
    input  wire              idelay_clk,   // FAST loader clock (125 MHz+)
    output wire              dout,
    output wire [CODE_WIDTH-1:0] cal_result,
    output wire              cal_valid
);

    localparam STAGES = MAIN_STAGES;
    localparam integer MAX_STEP_I = MAX_STEP;   // signed-capable copy for compares

    // -------------------------------------------------------------------------
    // Stepwise ramp: move loaded_code toward code by <= MAX_STEP taps/step.
    // -------------------------------------------------------------------------
    reg [CODE_WIDTH-1:0] loaded_code;
    wire signed [CODE_WIDTH:0] diff = $signed({1'b0, code}) - $signed({1'b0, loaded_code});
    reg signed [4:0] step;
    always @(*) begin
        if      (diff >  MAX_STEP_I) step =  MAX_STEP_I[4:0];
        else if (diff < -MAX_STEP_I) step = -MAX_STEP_I[4:0];
        else                         step = diff[4:0];   // |diff| <= MAX_STEP -> 1 step
    end
    wire busy = (diff != 0);
    // next_val is combo, ready the whole cycle before LOAD asserts.
    wire [CODE_WIDTH-1:0] next_val = loaded_code + step;

    reg load_pulse;
    always @(posedge idelay_clk or negedge rst_n) begin
        if (~rst_n) begin
            loaded_code <= {CODE_WIDTH{1'b0}};
            load_pulse  <= 1'b0;
        end else begin
            // advance one (<=8-tap) step per clock, back-to-back.
            loaded_code <= busy ? next_val : loaded_code;
            load_pulse  <= busy;   // 1-clock LOAD pulse only while a step is pending
        end
    end

    // -------------------------------------------------------------------------
    // Fabric-chained IDELAYE3 delay line (CASCADE="NONE", no LOC, no Route 35-19).
    // -------------------------------------------------------------------------
    wire [STAGES-1:0] main_do;

    genvar s;
    generate
        for (s = 0; s < STAGES; s = s + 1) begin : main_delay
            IDELAYE3 #(
                .CASCADE("NONE"), .DELAY_FORMAT("COUNT"), .DELAY_SRC("DATAIN"),
                .DELAY_TYPE("VAR_LOAD"), .DELAY_VALUE(0), .IS_CLK_INVERTED(1'b0),
                .IS_RST_INVERTED(1'b0),                 .REFCLK_FREQUENCY(300.0),
                .SIM_DEVICE("ULTRASCALE_PLUS"), .UPDATE_MODE("ASYNC")
            ) u_idelay (
                .CLK(idelay_clk), .CE(1'b0), .INC(1'b0),
                .CASC_IN(1'b0), .CASC_RETURN(1'b0), .CASC_OUT(),
                .IDATAIN(1'b0),
                .DATAIN((s == 0) ? din : main_do[s-1]),
                .LOAD(load_pulse),
                .CNTVALUEIN(next_val),
                .CNTVALUEOUT(), .DATAOUT(main_do[s]),
                .EN_VTC(1'b0), .RST(~rst_n)
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Auto-gate during ramp: only select the delayed path when settled.
    // While busy, output = din (raw, glitch-free); when settled, = delayed.
    // This hides the intermediate steps from the PLL (AR#67246 technique).
    // -------------------------------------------------------------------------
    assign dout = (idelay_en && !busy) ? main_do[STAGES-1] : din;

    // calibration ports kept for interface compatibility (no-op in this build)
    assign cal_result = {CODE_WIDTH{1'b0}};
    assign cal_valid  = 1'b0;

endmodule
