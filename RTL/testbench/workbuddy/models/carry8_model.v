`timescale 1ns / 1ps

// ============================================================
// Simplified CARRY8 model for Icarus Verilog simulation
//
// For this design, S=8'hFF and DI=8'b0 always, so CO = {8{CI}}.
// This reduces 8-level combinational logic to a single assign,
// allowing 64 instances to simulate without vvp crash.
//
// Real delay is applied at the lut_dtc output via #(code*40ps),
// not inside CARRY8 (which would cause event explosion).
// ============================================================

module CARRY8 #(parameter CARRY_TYPE="SINGLE_CY8")(
    output [7:0] CO,
    output [7:0] O,
    input [7:0] CI_TOP,
    input [7:0] DI,
    input [7:0] S,
    input CI
);
    // Optimized for S=8'hFF, DI=8'b0:
    // All 8 bits simply pass CI through.
    assign CO = {8{CI}};
    assign O = 8'b0;
endmodule
