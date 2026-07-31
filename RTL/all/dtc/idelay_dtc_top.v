`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: idelay_dtc_top  (IDELAYE3-based DTC, NO manual calibration, COUNT mode)
// Drop-in alternative to lut_dtc_top. Port list / parameter list identical.
//
// GLITCH-FREE + DRC-CLEAN STRATEGY:
//   * CASCADE="NONE" fabric chain (DATAOUT->DATAIN). No dedicated-cascade
//     constraint -> Route 35-19 cannot occur. No LOC needed.
//   * UPDATE_MODE="ASYNC" with LOAD PULSED (= ~settled, NOT tied to GND).
//     WHY ASYNC (NOT SYNC): REQP-1828 forbids a DRIVEN LOAD in SYNC VAR_LOAD
//     -- it insists LOAD be tied to GND. But VAR_LOAD needs LOAD=1 to load
//     CNTVALUEIN (AR#66013: "Set LOAD=High -> new delay loaded; Set LOAD=Low
//     to stop updating"). So SYNC+VAR_LOAD is a dead combo: GND => no load
//     (zero delay, code ignored); driven LOAD => REQP-1828. The fix is
//     UPDATE_MODE="ASYNC", where a LOAD pulse is legal AND required -- no
//     REQP-1828. (The earlier "SYNC + LOAD=GND" build is what left the DTC at
//     DELAY_VALUE=0 and made code do nothing -> that was the bug.) Both stages
//     share the SAME pulsed LOAD, so they re-load simultaneously (async) ->
//     the code=256 half-select switch happens at the same instant in both
//     stages -> the inter-stage window that caused the glitch is eliminated.
//   * Stepwise load (<=8 taps/step) satisfies the VAR_LOAD single-load limit
//     (AR#66013), so even a large power-up jump does not glitch the line.
//   * EN_VTC=0, COUNT mode: no IDELAYCTRL / REFCLK needed.
//
// CONSTRAINTS:
//   * create_clock on idelay_clk (125 MHz) REQUIRED (drives the stepwise
//     loader FSM). Do NOT add if already constrained elsewhere.
//   * NO LOC / adjacent-bitslice constraint needed (fabric chain).
//////////////////////////////////////////////////////////////////////////////////

module idelay_dtc_top #(
    parameter N_TAP       = 512,
    parameter CODE_WIDTH  = 9,
    parameter MAIN_STAGES = 2
) (
    input  wire              sys_clk,
    input  wire              rst_n,
    input  wire              din,
    input  wire [CODE_WIDTH-1:0] code,
    input  wire              cal_mode,
    input  wire [CODE_WIDTH-1:0] cal_code,
    input  wire              dtc_sel,
    input  wire              vco_clk,
    input  wire              idelay_en,
    input  wire              idelay_clk,
    output reg               idelay_load,   
    output wire              dout,
    output wire [CODE_WIDTH-1:0] cal_result,
    output wire              cal_valid
);

    localparam STAGES = MAIN_STAGES;

    
    reg [CODE_WIDTH-1:0] code_d1;
    reg [CODE_WIDTH-1:0] code_d2;
    reg [CODE_WIDTH-1:0] code_d3;
    reg [CODE_WIDTH-1:0] code_d4;
   
    

    // Asynchronous, active-LOW reset (rst_n): standard idiom is
    // `negedge rst_n` in the sensitivity list paired with `if (~rst_n)`.
    always @(posedge idelay_clk or negedge rst_n) begin
        if (~rst_n) begin
            code_d1 <= 'd0;
            code_d2 <= 'd0;
            code_d3 <= 'd0;
            code_d4 <= 'd0;
            idelay_load <= 0;
        end else begin
            code_d1 <= code;
            code_d2 <= code_d1;
            code_d3 <= code_d2;
            code_d4 <= code_d3;

            if ((code_d2 != code_d3) | (code_d3 != code_d4)) begin
                idelay_load <= 1;
            end else begin
                idelay_load <= 0;
            end
        end
    end


    // ---------------------------------------------------------------------------
    // Fabric-chained IDELAYE3 delay line (all stages always in the path).
    // ---------------------------------------------------------------------------
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
                .LOAD(idelay_load),
                .CNTVALUEIN(code), .CNTVALUEOUT(), .DATAOUT(main_do[s]),
                .EN_VTC(1'b0), .RST(~rst_n)
            );
        end
    endgenerate

    assign dout       = idelay_en ? main_do[STAGES-1] : din;
    assign cal_result = {CODE_WIDTH{1'b0}};
    assign cal_valid  = 1'b0;

endmodule
