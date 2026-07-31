`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// IDELAYE3 behavioral stand-in for iverilog (NOT a real silicon model).
//
// Validates the control-timing mechanism behind the 256 glitch in a 2-stage
// DATAOUT->DATAIN chain:
//   * ASYNC: stage1 (driven by stage0 output) starts switching SKEW_CYCLES
//     later than stage0 -> their switch windows are MIS-aligned -> cascade has
//     a wrong intermediate delay for a few cycles -> runt on final dout.
//   * SYNC : both stages triggered by the SAME external LD pulse -> windows
//     ALIGNED -> no intermediate wrong delay -> no runt.
//
// Mis-alignment is modeled in CLOCK CYCLES (integer) to stay iverilog-friendly.
// The model exposes switching_o / cross256_o so the TB computes inter-stage
// mis-alignment (the real glitch source) at top level.
//////////////////////////////////////////////////////////////////////////////////
module IDELAYE3 #(
    parameter CASCADE      = "NONE",
    parameter DELAY_FORMAT = "COUNT",
    parameter DELAY_SRC    = "DATAIN",
    parameter DELAY_TYPE   = "VAR_LOAD",
    parameter DELAY_VALUE  = 0,
    parameter IS_CLK_INVERTED = 1'b0,
    parameter IS_RST_INVERTED = 1'b0,
    parameter SIM_DEVICE   = "ULTRASCALE_PLUS",
    parameter UPDATE_MODE  = "SYNC",
    parameter SKEW_CYCLES = 0,    // cycles this stage starts late (ASYNC cascade)
    parameter SWITCH_CYCLES = 4   // cycles a switch takes to settle
) (
    input  wire CLK, CE, INC, LD, LOAD, EN_VTC, RST,
    input  wire CASC_IN, CASC_RETURN, IDATAIN, DATAIN,
    output wire CASC_OUT,
    output wire DATAOUT,
    input  wire [8:0] CNTVALUEIN,
    output wire [8:0] CNTVALUEOUT,
    output wire switching_o,
    output wire cross256_o
);

    reg [8:0] cur_taps = DELAY_VALUE[8:0];
    reg [8:0] tgt_taps = DELAY_VALUE[8:0];
    reg  switching;
    reg  cross256;
    integer start_cyc;
    integer cyc_cnt;
    reg [8:0] code_prev;

    wire load_event = (UPDATE_MODE=="SYNC") ? LD : LOAD;

    always @(posedge CLK or posedge RST) begin
        if (RST) cyc_cnt <= 0;
        else     cyc_cnt <= cyc_cnt + 1;
    end

    // ASYNC: with LOAD held high, any CNTVALUEIN change auto-triggers a reload on
    //        the next clock (no LD edge needed). SYNC: only on LD pulse.
    wire trigger;
    assign trigger = (UPDATE_MODE=="SYNC") ? LD : (CNTVALUEIN != code_prev);

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            tgt_taps  <= DELAY_VALUE[8:0];
            switching <= 1'b0;
            cross256 <= 1'b0;
            code_prev <= DELAY_VALUE[8:0];
        end else begin
            code_prev <= CNTVALUEIN;
            if (trigger) begin
                tgt_taps  <= CNTVALUEIN;
                switching <= (CNTVALUEIN != cur_taps);
                cross256 <= (CNTVALUEIN[8] != cur_taps[8]);
                start_cyc <= cyc_cnt + SKEW_CYCLES;  // ASYNC cascade lag
            end
        end
    end

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            cur_taps <= DELAY_VALUE[8:0];
            switching <= 1'b0;
        end else if (switching && (cyc_cnt >= start_cyc + SWITCH_CYCLES)) begin
            cur_taps <= tgt_taps;
            switching <= 1'b0;
        end
    end

    assign switching_o = switching;
    assign cross256_o  = cross256;

    // data path: delayed copy (cosmetic, for waveform)
    reg din_r;
    always @(posedge CLK) din_r <= (DELAY_SRC=="DATAIN") ? DATAIN : IDATAIN;
    reg [7:0] dly;
    always @(posedge CLK) dly <= {dly[6:0], din_r};
    assign DATAOUT = dly[2];
    assign CNTVALUEOUT = cur_taps;
    assign CASC_OUT = 1'b0;

endmodule
