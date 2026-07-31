`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ASYNC fabric-chain variant for glitch COMPARISON only (not for synthesis).
// UPDATE_MODE="ASYNC", LOAD held high (VAR_LOAD auto-refresh), NO LD pulse.
// This is the ORIGINAL buggy behavior that glitched at code=256.
//////////////////////////////////////////////////////////////////////////////////
module idelay_dtc_top_async #(
    parameter N_TAP=512, parameter CODE_WIDTH=9, parameter MAIN_STAGES=2
) (
    input  wire sys_clk, rst_n, din,
    input  wire [CODE_WIDTH-1:0] code,
    input  wire cal_mode, input wire [CODE_WIDTH-1:0] cal_code,
    input  wire dtc_sel, vco_clk, idelay_en, idelay_clk,
    output wire idelay_load, dout,
    output wire [CODE_WIDTH-1:0] cal_result, cal_valid
);
    localparam STAGES = MAIN_STAGES;
    wire [STAGES-1:0] main_do;
    genvar s;
    generate
        for (s=0; s<STAGES; s=s+1) begin : main_delay
            if (s==0) begin
                IDELAYE3 #(.CASCADE("NONE"),.DELAY_FORMAT("COUNT"),.DELAY_SRC("DATAIN"),
                    .DELAY_TYPE("VAR_LOAD"),.DELAY_VALUE(0),.REFCLK_FREQUENCY(300.0),
                    .SIM_DEVICE("ULTRASCALE_PLUS"),.UPDATE_MODE("ASYNC"))
                u_idelay (.CLK(idelay_clk),.CE(1'b0),.INC(1'b0),
                    .CASC_IN(1'b0),.CASC_RETURN(1'b0),.CASC_OUT(),
                    .IDATAIN(1'b0),.DATAIN(din),.LD(1'b0),.LOAD(idelay_load),
                    .CNTVALUEIN(code),.CNTVALUEOUT(),.DATAOUT(main_do[s]),
                    .EN_VTC(1'b0),.RST(~rst_n));
            end else begin
                IDELAYE3 #(.CASCADE("NONE"),.DELAY_FORMAT("COUNT"),.DELAY_SRC("DATAIN"),
                    .DELAY_TYPE("VAR_LOAD"),.DELAY_VALUE(0),.REFCLK_FREQUENCY(300.0),
                    .SIM_DEVICE("ULTRASCALE_PLUS"),.UPDATE_MODE("ASYNC"))
                u_idelay (.CLK(idelay_clk),.CE(1'b0),.INC(1'b0),
                    .CASC_IN(1'b0),.CASC_RETURN(1'b0),.CASC_OUT(),
                    .IDATAIN(1'b0),.DATAIN(main_do[s-1]),.LD(1'b0),.LOAD(idelay_load),
                    .CNTVALUEIN(code),.CNTVALUEOUT(),.DATAOUT(main_do[s]),
                    .EN_VTC(1'b0),.RST(~rst_n));
            end
        end
    endgenerate
    assign dout = idelay_en ? main_do[STAGES-1] : din;
    assign idelay_load = 1'b1;   // ASYNC: LOAD held high
    assign cal_result = {CODE_WIDTH{1'b0}};
    assign cal_valid  = 1'b0;
endmodule
