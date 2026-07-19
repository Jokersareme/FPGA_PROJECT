`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: carry8_model
// Description: Behavioral model of Xilinx CARRY8 (SINGLE_CY8 mode)
//              for RTL simulation with iverilog (which doesn't have
//              Xilinx primitives).
//
//              CO[i] = CI when S[i]=1 (carry propagation), else DI[i]
//              In lut_dtc, S=8'hFF and DI=0, so CO[i] = carry from
//              previous stage. CO[0]=CI, CO[1]=CO[0], etc.
//              -> acts as a delay chain through CI->CO[0]->CO[1]->...
//
//              NO gate delay in this model. For real delay, use
//              Vivado post-synthesis sim with SDF.
//////////////////////////////////////////////////////////////////////////////////
module CARRY8 #(
    parameter CARRY_TYPE = "SINGLE_CY8"
)(
    output reg [7:0] CO,
    output     [7:0] O,
    input      [7:0] CI_TOP,
    input      [7:0] DI,
    input      [7:0] S,
    input            CI
);

    // SINGLE_CY8: CO[0] = CI, CO[i] = S[i] ? CO[i-1] : DI[i]
    // With S=0xFF, DI=0: CO[0]=CI, CO[i]=CO[i-1] -> all equal CI
    // (This is correct behavior: in real HW the delay differs per tap,
    //  but logically all CO bits follow CI)
    always @(*) begin
        CO[0] = (S[0]) ? CI      : DI[0];
        CO[1] = (S[1]) ? CO[0]   : DI[1];
        CO[2] = (S[2]) ? CO[1]   : DI[2];
        CO[3] = (S[3]) ? CO[2]   : DI[3];
        CO[4] = (S[4]) ? CO[3]   : DI[4];
        CO[5] = (S[5]) ? CO[4]   : DI[5];
        CO[6] = (S[6]) ? CO[5]   : DI[6];
        CO[7] = (S[7]) ? CO[6]   : DI[7];
    end

    assign O = 8'b0;

endmodule
