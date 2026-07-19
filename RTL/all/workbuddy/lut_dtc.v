`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: lut_dtc
// Description: Dual-path 512-tap CARRY8 DTC with dtc_sel switch
//
// Both paths fix the original 100ps problem by replacing the single 512:1
// MUX (9-layer LUT tree) with 2-stage MUXes (5-layer LUT), letting the
// CARRY8 carry-chain delay (15ps/tap) show through.
//
// Path A (dtc_sel=0): 512 tap, 8:1 segment + 64:1 intra-segment MUX
// Path B (dtc_sel=1): 512 tap, 4:1 segment + 128:1 intra-segment MUX
//
// Both paths: 9-bit code, ~7.68ns per stage, 5-stage cascade ~38ns max.
// Different MUX segmentation -> different delay characteristics for
// comparison/verification.
//
// Interface: original ports + one new input (dtc_sel).
// No extra clock, no IDELAYE3, no IP changes.
//////////////////////////////////////////////////////////////////////////////////
module lut_dtc #(
    parameter N_TAP = 512,
    parameter CODE_WIDTH = 9
)(
    input  wire                      sys_clk,
    input  wire                      rst_n,
    input  wire                      din,
    input  wire [CODE_WIDTH-1:0]     code,
    input  wire                      cal_mode,
    input  wire                      dtc_sel,       // 0=Path A, 1=Path B
    output wire                      dout,
    output reg  [CODE_WIDTH-1:0]     cal_result,
    output reg                       cal_valid
);

    // ========================================================================
    // Shared CARRY8 carry chain (512 taps, used by both paths)
    // ========================================================================
    localparam N_CARRY = N_TAP / 8;          // 64 CARRY8

    (* KEEP = "TRUE" *) wire [7:0] co [0:N_CARRY-1];
    (* KEEP = "TRUE" *) wire [N_TAP-1:0] tap;  // 512 taps flat

    genvar i, j;
    generate
        for (i = 0; i < N_CARRY; i = i + 1) begin : flatten
            for (j = 0; j < 8; j = j + 1) begin : tap_map
                assign tap[i*8+j] = co[i][j];
            end
        end
    endgenerate

    (* DONT_TOUCH = "TRUE" *)
    CARRY8 #(
        .CARRY_TYPE("SINGLE_CY8")
    ) u_carry_0 (
        .CO     (co[0]),
        .O      (),
        .CI     (din),
        .CI_TOP (1'b0),
        .DI     (8'b0),
        .S      (8'hFF)
    );

    generate
        for (i = 1; i < N_CARRY; i = i + 1) begin : cascade
            (* DONT_TOUCH = "TRUE" *)
            CARRY8 #(
                .CARRY_TYPE("SINGLE_CY8")
            ) u_carry (
                .CO     (co[i]),
                .O      (),
                .CI     (co[i-1][7]),
                .CI_TOP (1'b0),
                .DI     (8'b0),
                .S      (8'hFF)
            );
        end
    endgenerate

    // ========================================================================
    // PATH A: 8:1 segment select + 64:1 intra-segment select
    //   code[8:6] -> segment (8 segments x 64 taps)
    //   code[5:0] -> tap within segment
    //   MUX depth: 2 + 3 = 5 LUT layers
    // ========================================================================
    localparam SEG_TAPS_A = 64;   // 64 taps per segment

    wire [2:0] seg_sel_a   = code[8:6];
    wire [5:0] tap_in_seg_a = code[5:0];

    reg [SEG_TAPS_A-1:0] seg_taps_a;
    always @(*) begin
        case (seg_sel_a)
            3'd0: seg_taps_a = tap[SEG_TAPS_A*1-1 : SEG_TAPS_A*0];
            3'd1: seg_taps_a = tap[SEG_TAPS_A*2-1 : SEG_TAPS_A*1];
            3'd2: seg_taps_a = tap[SEG_TAPS_A*3-1 : SEG_TAPS_A*2];
            3'd3: seg_taps_a = tap[SEG_TAPS_A*4-1 : SEG_TAPS_A*3];
            3'd4: seg_taps_a = tap[SEG_TAPS_A*5-1 : SEG_TAPS_A*4];
            3'd5: seg_taps_a = tap[SEG_TAPS_A*6-1 : SEG_TAPS_A*5];
            3'd6: seg_taps_a = tap[SEG_TAPS_A*7-1 : SEG_TAPS_A*6];
            3'd7: seg_taps_a = tap[SEG_TAPS_A*8-1 : SEG_TAPS_A*7];
            default: seg_taps_a = tap[SEG_TAPS_A*1-1 : SEG_TAPS_A*0];
        endcase
    end

    wire dout_a = (tap_in_seg_a < SEG_TAPS_A) ? seg_taps_a[tap_in_seg_a]
                                               : seg_taps_a[SEG_TAPS_A-1];

    // ========================================================================
    // PATH B: 4:1 segment select + 128:1 intra-segment select
    //   code[8:7] -> segment (4 segments x 128 taps)
    //   code[6:0] -> tap within segment
    //   MUX depth: 1 + 3 = 4 LUT layers (shallower than Path A)
    // ========================================================================
    localparam SEG_TAPS_B = 128;  // 128 taps per segment

    wire [1:0] seg_sel_b   = code[8:7];
    wire [6:0] tap_in_seg_b = code[6:0];

    reg [SEG_TAPS_B-1:0] seg_taps_b;
    always @(*) begin
        case (seg_sel_b)
            2'd0: seg_taps_b = tap[SEG_TAPS_B*1-1 : SEG_TAPS_B*0];
            2'd1: seg_taps_b = tap[SEG_TAPS_B*2-1 : SEG_TAPS_B*1];
            2'd2: seg_taps_b = tap[SEG_TAPS_B*3-1 : SEG_TAPS_B*2];
            2'd3: seg_taps_b = tap[SEG_TAPS_B*4-1 : SEG_TAPS_B*3];
            default: seg_taps_b = tap[SEG_TAPS_B*1-1 : SEG_TAPS_B*0];
        endcase
    end

    wire dout_b = (tap_in_seg_b < SEG_TAPS_B) ? seg_taps_b[tap_in_seg_b]
                                               : seg_taps_b[SEG_TAPS_B-1];

    // ========================================================================
    // Output MUX: dtc_sel selects between Path A and Path B
    // ========================================================================
    assign dout = dtc_sel ? dout_b : dout_a;

endmodule
