`timescale 1ns/1ps
// =============================================================================
// Behavioral verification of dtc_cal_top's BBPD+LMS loop under SSC modulation.
//
// GOAL: answer the user's worry —
//   "phase_align_cal too slow to follow SSC corners? gain biased by SSC?"
//
// METHOD (storage-safe, no VCD):
//   * Real calibration RTL is used VERBATIM:
//       - dtc_gain_lms_cal   (sign-sign LMS, the actual algorithm)
//       - phase_align_cal    (slow integrator, the actual algorithm)
//   * Only the analog/CARRY8 parts are modeled behaviorally:
//       - the DTC delay is replaced by a phase term in "ticks"
//       - cal_sign_gen truth table (sign=1 when fb leads ref) is computed directly
//   * A dither is injected into dtc_code so the LMS has a clean gradient
//     (this is exactly what the cited literature, Markulic 2016, requires;
//      the real design takes d_dtc from the background code — see notes).
//   * dtc_code also gets occasional BIG JUMPS to emulate 2nd-order MASH carry.
//
// Two runs:  -DSSC_ON=0  (SSC off, baseline)
//            -DSSC_ON=1  (SSC on,  triangle phase modulation +/-SSC_AMP ticks)
//
// Expect: gain_corrected converges to GAIN_TRUE in BOTH runs (SSC does NOT bias
// it, only adds jitter); delay_code stays ~constant (slow loop filters SSC).
// =============================================================================
`ifndef SSC_ON
  `define SSC_ON 0
`endif

module tb;

  // ---- synthetic phase scale (ticks per ref period) ----
  parameter N_FINE    = 192;     // phase resolution
  parameter GAIN_TRUE = 600;     // "true" DTC gain hardware actually has
  parameter SCALE     = 64;      // residual = gerr * d_signed / SCALE  (ticks)
  parameter STATIC    = 30;      // static fb-lead the phase_align must null
  parameter PSCALE    = 2;       // delay_code(5b, centered 16) -> ticks
  parameter SSC_AMP   = 16;      // SSC peak phase deviation (ticks)
  parameter CENTER    = 256;     // DTC null point (signed code reference)

  reg tb_clk;
  initial tb_clk = 0;            // MUST init or ~x stays x -> no edges
  always #5 tb_clk = ~tb_clk;    // 10 ns update tick (no fine clock needed)

  reg rst_n, cal_start;
  reg ssc_en = `SSC_ON;

  // ---- dtc_code stimulus: center + injected dither +/-20 + mash noise +/-5
  //      + occasional big jump (+150) to emulate 2nd-order MASH carry ----
  reg        dith_pol;
  reg signed [7:0] dither;
  reg signed [4:0] W;
  reg [8:0]  dtc_code;
  reg [8:0]  dtc_code_d1;
  reg [15:0] lfsr;
  reg [31:0] cyc;
  reg        big_jump;

  // ---- SSC triangle phase (ticks) ----
  reg signed [11:0] ssc_phase;
  reg               ssc_dir;

  // ---- real calibration RTL (verbatim algorithm) ----
  wire [9:0] gain_est;
  wire [4:0] delay_code;

  phase_align_cal #(.ACCUM_WIDTH(14), .DELAY_WIDTH(5)) u_pa (
    .clk(tb_clk), .rst_n(rst_n), .sign_in(pd_sign), .delay_code(delay_code));

  dtc_gain_lms_cal #(.ACCUM_WIDTH(16), .CODE_WIDTH(9),
                     .GAIN_BASE_WIDTH(10), .GAIN_ADJ_WIDTH(10)) u_lms (
    .clk(tb_clk), .rst_n(cal_start),
    .sign_in(pd_sign), .dtc_code_in(dtc_code_d1),
    .gain_base(10'd512), .gain_corrected(gain_est));

  // ---- BBPD phase math (cal_sign_gen truth table: sign=1 => fb leads) ----
  reg signed [31:0] NF;
  reg signed [31:0] eff;
  reg signed [31:0] r;
  reg [31:0] phi;
  reg pd_sign;

  wire signed [31:0] gerr      = GAIN_TRUE - $signed({1'b0, gain_est});
  wire signed [31:0] d_signed  = $signed({1'b0, dtc_code}) - CENTER;
  wire signed [31:0] gain_part = (gerr * d_signed) / SCALE;
  wire signed [31:0] pa_term   = ($signed({1'b0, delay_code}) - 16) * PSCALE;

  // Registered (NOT combinational) to avoid a zero-delay combinational loop
  // through the calibration RTL feedback (iverilog would resolve it as x).
  always @(posedge tb_clk or negedge rst_n) begin
    if (!rst_n) begin
      pd_sign <= 1'b0;
    end else begin
      NF  = N_FINE;
      eff = gain_part + STATIC + (ssc_en ? ssc_phase : 0) - pa_term;
      r   = eff % NF;
      if (eff < 0) phi = NF + r; else phi = r;          // wrap into [0, N_FINE)
      pd_sign <= (phi < (N_FINE/2)) ? 1'b1 : 1'b0;
    end
  end

  // ---- stimulus generation ----
  // NOTE: update on NEGEDGE so that at the posedge (when pd_sign + the real
  // calibration RTL sample dtc_code/ssc_phase) these signals are already
  // stable. This avoids a same-edge race that briefly produced 'x' and got
  // latched into the integrators (permanent 'x' lockup).
  // ALSO: initialize all stimulus regs at t=0 so the very first posedge
  // (before any negedge) already sees defined values -> no 'x' poisoning.
  initial begin
    dtc_code = CENTER; dtc_code_d1 = CENTER;
    dither = 8'sd20; W = 0; lfsr = 16'h1234; dith_pol = 1'b1;
    ssc_phase = 0; ssc_dir = 1'b1;
  end
  always @(negedge tb_clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr<=16'h1234; dith_pol<=1'b1; W<=0;
      dtc_code<=CENTER; dtc_code_d1<=CENTER; cyc<=0;
      ssc_phase<=0; ssc_dir<=1'b1; big_jump<=1'b0;
    end else begin
      cyc <= cyc + 1;
      lfsr <= lfsr*16'h1234 + 16'h9e37;
      dith_pol <= ~dith_pol;
      dither   <= dith_pol ? 8'sd20 : -8'sd20;
      if (lfsr[0]) W <= (W>5)?5:W+1; else W <= (W< -5)?-5:W-1;
      big_jump <= (cyc[7:0]==8'd0);
      if (big_jump) dtc_code <= $signed(dtc_code) + 9'sd150;
      else          dtc_code <= CENTER + $signed(dither) + $signed(W);
      dtc_code_d1 <= dtc_code;
      if (ssc_en) begin
        if (ssc_dir) ssc_phase <= (ssc_phase>=SSC_AMP)?SSC_AMP:ssc_phase+1;
        else         ssc_phase <= (ssc_phase<=-SSC_AMP)?-SSC_AMP:ssc_phase-1;
        if (ssc_phase>=SSC_AMP)  ssc_dir<=1'b0;
        if (ssc_phase<=-SSC_AMP) ssc_dir<=1'b1;
      end
    end
  end

  initial begin
    rst_n=0; cal_start=0;
    #200 rst_n=1;
    #500 cal_start=1;
  end

  // ---- reporting ----
  integer gmin,gmax,dmin,dmax;
  initial begin
    gmin=1023; gmax=0; dmin=31; dmax=0;
    #200;
    forever begin
      @(posedge tb_clk);
      if (cyc>40000) begin
        if (gain_est<gmin) gmin=gain_est;
        if (gain_est>gmax) gmax=gain_est;
        if (delay_code<dmin) dmin=delay_code;
        if (delay_code>dmax) dmax=delay_code;
      end
      if (cyc%4000==0)
        $display("cyc=%0d gain=%0d delay=%0d ssc_en=%0d ssc=%0d pd=%0b",
                 cyc,gain_est,delay_code,ssc_en,ssc_phase,pd_sign);
      if (cyc>=60000) begin
        $display("=== RESULT ssc_en=%0b  GAIN_TRUE=%0d  gain_base=512 ===", ssc_en, GAIN_TRUE);
        $display("  gain  steady min=%0d max=%0d spread=%0d  (target %0d)",
                 gmin, gmax, gmax-gmin, GAIN_TRUE);
        $display("  delay steady min=%0d max=%0d  (STATIC=%0d -> expect ~%0d, must NOT track ssc)",
                 dmin, dmax, STATIC, 16 + STATIC/PSCALE);
        $display("  UNBIASED_BY_SSC: %s",
                 ((gmin>GAIN_TRUE-10)&&(gmax<GAIN_TRUE+10)) ? "YES" : "NO");
        $finish;
      end
    end
  end

endmodule
