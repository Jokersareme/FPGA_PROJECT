`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Behavioral stub for IDELAYE3 (for iverilog simulation only).
// NOT synthesizable. Replaces the Xilinx UNISIM primitive so we can verify the
// loader FSM without Vivado. It latches CNTVALUEIN on the LOAD pulse (ASYNC) and
// applies a coarse delay = taps * 1ps to DATAIN so dout visibly lags din.
//////////////////////////////////////////////////////////////////////////////////
module IDELAYE3 #(
    parameter CASCADE       = "NONE",
    parameter DELAY_FORMAT  = "COUNT",
    parameter DELAY_SRC     = "DATAIN",
    parameter DELAY_TYPE    = "VAR_LOAD",
    parameter DELAY_VALUE   = 0,
    parameter IS_CLK_INVERTED = 1'b0,
    parameter IS_RST_INVERTED  = 1'b0,
    parameter real REFCLK_FREQUENCY = 300.0,
    parameter SIM_DEVICE    = "ULTRASCALE_PLUS",
    parameter UPDATE_MODE   = "ASYNC"
) (
    output wire        CASC_OUT,
    output wire [8:0]  CNTVALUEOUT,
    output wire        DATAOUT,
    input  wire        CASC_IN,
    input  wire        CASC_RETURN,
    input  wire        CE,
    input  wire        CLK,
    input  wire [8:0]  CNTVALUEIN,
    input  wire        DATAIN,
    input  wire        EN_VTC,
    input  wire        IDATAIN,
    input  wire        INC,
    input  wire        LOAD,
    input  wire        RST
);
    reg [8:0] taps;
    reg       dout_r;

    // ASYNC load: latch CNTVALUEIN on LOAD pulse.
    always @(posedge LOAD or posedge RST) begin
        if (RST)      taps <= 9'd0;
        else if (LOAD) taps <= CNTVALUEIN;
    end
    assign CNTVALUEOUT = taps;

    // Coarse behavioral delay: dout lags din by `taps` ps (1ps per tap in sim).
    always @(DATAIN or taps) begin
        #(taps) dout_r = (DELAY_SRC == "IDATAIN") ? IDATAIN : DATAIN;
    end
    assign DATAOUT = dout_r;

    assign CASC_OUT = 1'b0;
endmodule
