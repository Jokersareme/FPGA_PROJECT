`timescale 1ns / 1ps
// Behavioral DTC delay with configurable taps
// Each tap = 10ps. For N_TAP=64: 64*10ps = 640ps max delay
// Fast simulation: each edge creates N_TAP assign # events
module behavior_dtc #(parameter N_TAP = 64) (
    input  wire             din,
    input  wire [8:0]       code,
    output wire             dout
);
    wire [N_TAP-1:0] dly;
    assign #0.010 dly[0] = din;
    genvar i;
    generate
        for (i = 1; i < N_TAP; i = i + 1) begin : chain
            assign #0.010 dly[i] = dly[i-1];
        end
    endgenerate
    assign dout = dly[code[5:0]];  // truncate 9-bit code to 6 bits for 64 taps
endmodule
