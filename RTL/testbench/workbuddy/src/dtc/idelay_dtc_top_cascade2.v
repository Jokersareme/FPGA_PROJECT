`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: idelay_dtc_top_cascade2
//   IDELAYE3-based DTC, 2-STAGE DEDICATED CASCADE, COUNT mode.
//   Drop-in replacement for lut_dtc_top. Use ONLY if you need 2x VCO-period
//   range margin (e.g. you want headroom above T_VCO).
//
// ============================================================================
// WHY DEDICATED CASCADE (not the fabric chain that failed before)
// ----------------------------------------------------------------------------
// The earlier fabric chain (CASCADE="NONE", stage.s DATAOUT -> stage.s+1
// DATAIN over general routing) glitched at code=256 because the two separate
// IDELAYE3s' internal half-select switches were not time-aligned.
//
// The DEDICATED cascade (MASTER -> SLAVE_END) routes the delayed signal on the
// characterized CASC_OUT -> CASC_IN net and requires the two IDELAYE3s to be
// placed in ADJACENT BITSLICEs. Xilinx designed this path so the stages update
// aligned -> no 256 glitch. This is exactly the topology used in the published
// 3-stage ODELAYE3 cascade example (MicroZed Chronicles, ASYNC + LOAD pulse).
//
// ============================================================================
// IMPORTANT - GAIN IS DOUBLED vs the single-stage version
// ----------------------------------------------------------------------------
// Both stages get the SAME `code`, so total delay = 2 * code * per_tap.
// That doubles the DTC gain vs dtc_comp's assumption (0..511 = 0..T_VCO at 1x).
// You MUST re-map in dtc_comp, either:
//   (a) feed the stages with code>>1 (keeps 0..T_VCO range, but loses 1 bit of
//       resolution -> 256 effective steps, LSB ~ 2x), or
//   (b) keep code as-is and halve the digital gain in dtc_comp (e1*gain>>12,
//       or gain_base halved).
// This file feeds the RAW `code` (option b is left to dtc_comp). If you prefer
// (a), change the CNTVALUEIN connection to (ld_value >> 1) in both stages.
//
// ============================================================================
// LOAD SEQUENCE (same as single-stage): VAR_LOAD + ASYNC, clean 1-clk pulse,
// <=8 taps/step. Both stages share the SAME pulsed LOAD and the SAME ld_value,
// so they update together. ASYNC avoids REQP-1828 (which only fires in SYNC).
//
// CONSTRAINTS:
//   * create_clock on idelay_clk (e.g. 125 MHz).
//   * COUNT mode: no IDELAYCTRL, EN_VTC = 0.
//   * ADJACENT BITSLICE LOC is MANDATORY (see idelay_cascade2.xdc), else
//     implementation fails with Route 35-19 ("no CASC path").
//////////////////////////////////////////////////////////////////////////////////

module idelay_dtc_top_cascade2 #(
    parameter N_TAP      = 512,
    parameter CODE_WIDTH = 9
) (
    input  wire                   sys_clk,
    input  wire                   rst_n,
    input  wire                   din,
    input  wire [CODE_WIDTH-1:0]  code,
    input  wire                   cal_mode,
    input  wire [CODE_WIDTH-1:0]  cal_code,
    input  wire                   dtc_sel,
    input  wire                   vco_clk,
    input  wire                   idelay_en,
    input  wire                   idelay_clk,
    output wire                   idelay_load,
    output wire                   dout,
    output wire [CODE_WIDTH-1:0]  cal_result,
    output wire                   cal_valid
);

    // ------------------------------------------------------------------
    // Stepwise loader FSM (identical to single-stage).
    // ------------------------------------------------------------------
    reg [CODE_WIDTH-1:0] loaded_code;
    reg [CODE_WIDTH-1:0] ld_value;
    reg                  armed;
    reg                  load_pulse;

    wire signed [CODE_WIDTH:0] diff = $signed({1'b0, code}) - $signed({1'b0, loaded_code});
    wire        moving = (diff != 0);

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

    always @(posedge idelay_clk or negedge rst_n) begin
        if (~rst_n) begin
            loaded_code <= {CODE_WIDTH{1'b0}};
            ld_value    <= {CODE_WIDTH{1'b0}};
            armed       <= 1'b0;
            load_pulse  <= 1'b0;
        end else begin
            load_pulse <= 1'b0;
            if (moving) begin
                if (~armed) begin
                    ld_value <= next_val;
                    armed    <= 1'b1;
                end else begin
                    load_pulse  <= 1'b1;
                    loaded_code <= ld_value;
                    armed       <= 1'b0;
                end
            end else begin
                armed <= 1'b0;
            end
        end
    end

    assign idelay_load = load_pulse;

    // ------------------------------------------------------------------
    // 2-stage dedicated cascade: MASTER -> SLAVE_END.
    // ------------------------------------------------------------------
    wire       casc0;
    wire       dout_int;

    IDELAYE3 #(
        .CASCADE("MASTER"),
        .DELAY_FORMAT("COUNT"),
        .DELAY_SRC("DATAIN"),
        .DELAY_TYPE("VAR_LOAD"),
        .DELAY_VALUE(0),
        .IS_CLK_INVERTED(1'b0),
        .IS_RST_INVERTED(1'b0),
        .REFCLK_FREQUENCY(300.0),
        .SIM_DEVICE("ULTRASCALE_PLUS"),
        .UPDATE_MODE("ASYNC")
    ) u_master (
        .CLK(idelay_clk),
        .CE(1'b0),
        .INC(1'b0),
        .CASC_IN(1'b0),
        .CASC_RETURN(1'b0),
        .CASC_OUT(casc0),
        .IDATAIN(1'b0),
        .DATAIN(din),
        .LOAD(idelay_load),
        .CNTVALUEIN(ld_value),
        .CNTVALUEOUT(),
        .DATAOUT(),        // not used in cascade; final output is SLAVE_END
        .EN_VTC(1'b0),
        .RST(~rst_n)
    );

    IDELAYE3 #(
        .CASCADE("SLAVE_END"),
        .DELAY_FORMAT("COUNT"),
        .DELAY_SRC("DATAIN"),
        .DELAY_TYPE("VAR_LOAD"),
        .DELAY_VALUE(0),
        .IS_CLK_INVERTED(1'b0),
        .IS_RST_INVERTED(1'b0),
        .REFCLK_FREQUENCY(300.0),
        .SIM_DEVICE("ULTRASCALE_PLUS"),
        .UPDATE_MODE("ASYNC")
    ) u_slave (
        .CLK(idelay_clk),
        .CE(1'b0),
        .INC(1'b0),
        .CASC_IN(casc0),
        .CASC_RETURN(casc0),
        .CASC_OUT(),
        .IDATAIN(1'b0),
        .DATAIN(1'b0),
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
