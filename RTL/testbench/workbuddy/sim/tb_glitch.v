`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Glitch comparison: 2-stage DATAOUT->DATAIN IDELAYE3 chain.
//   ASYNC: LOAD held high, stage1 starts SKEW_CYCLES later than stage0
//          -> switch windows MIS-aligned -> runt on final dout at 256 cross.
//   SYNC : same external LD pulse -> both start same cycle -> windows ALIGNED
//          -> no runt.
// (SKEW_CYCLES models the fabric arrival skew between two IOBs.)
//////////////////////////////////////////////////////////////////////////////////
module tb_glitch;
    reg idelay_clk, din, rst_n;
    reg [8:0] code;
    localparam integer SKEW = 3;   // cycles stage1 lags stage0 (ASYNC)

    // ===================== ASYNC chain =====================
    wire a_dout, a_s0_sw, a_s0_c256, a_s1_sw, a_s1_c256;
    wire a_ld = 1'b0;
    IDELAYE3 #(.UPDATE_MODE("ASYNC"),.DELAY_SRC("DATAIN"),.SKEW_CYCLES(0))
        a_s0 (.CLK(idelay_clk),.CE(1'b0),.INC(1'b0),.LD(a_ld),.LOAD(1'b1),
              .CASC_IN(1'b0),.CASC_RETURN(1'b0),.CASC_OUT(),.IDATAIN(1'b0),
              .DATAIN(din),.CNTVALUEIN(code),.CNTVALUEOUT(),.DATAOUT(a_mid),
              .EN_VTC(1'b0),.RST(~rst_n),.switching_o(a_s0_sw),.cross256_o(a_s0_c256));
    wire a_mid;
    IDELAYE3 #(.UPDATE_MODE("ASYNC"),.DELAY_SRC("DATAIN"),.SKEW_CYCLES(SKEW))
        a_s1 (.CLK(idelay_clk),.CE(1'b0),.INC(1'b0),.LD(a_ld),.LOAD(1'b1),
              .CASC_IN(1'b0),.CASC_RETURN(1'b0),.CASC_OUT(),.IDATAIN(1'b0),
              .DATAIN(a_mid),.CNTVALUEIN(code),.CNTVALUEOUT(),.DATAOUT(a_dout),
              .EN_VTC(1'b0),.RST(~rst_n),.switching_o(a_s1_sw),.cross256_o(a_s1_c256));

    // ===================== SYNC chain =====================
    wire s_dout, s_s0_sw, s_s0_c256, s_s1_sw, s_s1_c256;
    reg s_ld;
    reg [8:0] code_r; reg need_ld;
    always @(posedge idelay_clk or posedge rst_n) begin
        if (~rst_n) begin code_r<=0; need_ld<=1'b1; end
        else begin code_r<=code; need_ld<=(code!=code_r); end
    end
    always @(posedge idelay_clk) s_ld <= need_ld;
    IDELAYE3 #(.UPDATE_MODE("SYNC"),.DELAY_SRC("DATAIN"),.SKEW_CYCLES(0))
        s_s0 (.CLK(idelay_clk),.CE(1'b0),.INC(1'b0),.LD(s_ld),.LOAD(1'b0),
              .CASC_IN(1'b0),.CASC_RETURN(1'b0),.CASC_OUT(),.IDATAIN(1'b0),
              .DATAIN(din),.CNTVALUEIN(code),.CNTVALUEOUT(),.DATAOUT(s_mid),
              .EN_VTC(1'b0),.RST(~rst_n),.switching_o(s_s0_sw),.cross256_o(s_s0_c256));
    wire s_mid;
    IDELAYE3 #(.UPDATE_MODE("SYNC"),.DELAY_SRC("DATAIN"),.SKEW_CYCLES(0))
        s_s1 (.CLK(idelay_clk),.CE(1'b0),.INC(1'b0),.LD(s_ld),.LOAD(1'b0),
              .CASC_IN(1'b0),.CASC_RETURN(1'b0),.CASC_OUT(),.IDATAIN(1'b0),
              .DATAIN(s_mid),.CNTVALUEIN(code),.CNTVALUEOUT(),.DATAOUT(s_dout),
              .EN_VTC(1'b0),.RST(~rst_n),.switching_o(s_s1_sw),.cross256_o(s_s1_c256));

    always #8 idelay_clk = ~idelay_clk;
    always #20 din = ~din;

    // glitch = the cascade passes through an ILLEGAL intermediate state where
    // stage0 has updated but stage1 has NOT (or vice versa) while crossing 256.
    // ASYNC: stage1 lags SKEW cycles -> this window exists for SKEW cycles -> runt.
    // SYNC : both update same cycle -> no such window -> no runt.
    // We flag it when a 256-cross is in progress AND the two stages are NOT in
    // the same "phase" (one switching, other settled / both switching but the
    // lag creates the disjoint window). Simplest faithful proxy:
    //   mid-cross on stage0  AND  (stage1 not yet started OR stage1 already done)
    // captured by comparing switching flags across the lag.
    reg a_gl, s_gl;
    always @(posedge idelay_clk) begin
        // ASYNC: stage1 lags -> window where s0 active & s1 not-yet-active (or s1
        // active & s0 already settled). Model: mismatch of switching flags while
        // at least one is a 256-cross.
        a_gl <= (a_s0_sw ^ a_s1_sw) & (a_s0_c256 | a_s1_c256);
        // SYNC: flags always equal -> mismatch never -> no glitch.
        s_gl <= (s_s0_sw ^ s_s1_sw) & (s_s0_c256 | s_s1_c256);
    end

    integer cyc, a_cnt, s_cnt;
    initial begin
        idelay_clk=0; din=0; rst_n=0; code=9'd250; a_cnt=0; s_cnt=0;
        #200; rst_n=1; #200; repeat(20) @(posedge idelay_clk);

        for (cyc=250; cyc<=300; cyc=cyc+1) begin code=cyc[8:0]; repeat(30) @(posedge idelay_clk); end
        for (cyc=300; cyc>=200; cyc=cyc-1) begin code=cyc[8:0]; repeat(30) @(posedge idelay_clk); end
        code=9'd50; repeat(60) @(posedge idelay_clk);

        $display("RESULT ASYNC 256-cross glitch cycles = %0d", a_cnt);
        $display("RESULT SYNC  256-cross glitch cycles = %0d", s_cnt);
        $finish;
    end
    always @(posedge idelay_clk) begin
        if (a_gl) a_cnt <= a_cnt + 1;
        if (s_gl) s_cnt <= s_cnt + 1;
    end
    initial begin $dumpfile("tb_glitch.vcd"); $dumpvars(0, tb_glitch); end
endmodule
