`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_cal_modules (v6 — 确定性序列验证)
//
//   Phase 3: sign=0, dtc_code 递增 (d_dtc=1) × 20000 → 全 corr=1 → accum- → gain↓
//   Phase 4: sign=1, dtc_code 递增 (d_dtc=1) × 20000 → 全 corr=0 → accum+ → gain↑
//   Phase 5: sign=0, dtc_code 递减 (d_dtc=0) × 20000 → 全 corr=0 → accum+ → gain↑
//   Phase 6: sign=1, dtc_code 递减 (d_dtc=0) × 20000 → 全 corr=1 → accum- → gain↓
////////////////////////////////////////////////////////////////////////////////

module tb_cal_modules;

    parameter SYS_CLK_PERIOD = 8.0;
    reg sys_clk = 0; reg ref_clk = 0; reg fb_clk = 0; reg rst_n = 0;
    always #(SYS_CLK_PERIOD/2) sys_clk = ~sys_clk;
    always #50 ref_clk = ~ref_clk;

    wire sign_bbpd;
    wire [4:0] delay_code;
    wire [9:0] gain_corrected;
    reg sign_dtc = 0;
    reg [8:0] dtc_code_v = 256;
    reg [9:0] gain_base_v = 512;

    cal_sign_gen u_cal_sign (.clk_ref(ref_clk), .clk_fb(fb_clk), .rst_n(rst_n), .sign(sign_bbpd));
    phase_align_cal #(.ACCUM_WIDTH(14), .DELAY_WIDTH(5)) u_phase_align (
        .clk(sys_clk), .rst_n(rst_n), .sign_in(sign_bbpd), .delay_code(delay_code));
    dtc_gain_lms_cal #(.CODE_WIDTH(9), .GAIN_BASE_WIDTH(10),
        .GAIN_ADJ_WIDTH(10), .ACCUM_WIDTH(16)) u_dtc_gain_lms (
        .clk(sys_clk), .rst_n(rst_n), .sign_in(sign_dtc),
        .dtc_code_in(dtc_code_v), .gain_base(gain_base_v), .gain_corrected(gain_corrected));

    integer phase, t;

    initial begin
        $dumpfile("tb_cal_modules.vcd");
        $dumpvars(0, tb_cal_modules);
        $display("=== Starting ===");

        phase = 0; rst_n = 0; #200; rst_n = 1; #1000;
        $display("[%0t] Init", $time);

        // Phase 1: BBPD
        phase = 1; fb_clk = ref_clk; #2000; fb_clk = ~ref_clk; #2000;
        fb_clk = ref_clk; #2000;
        $display("[%0t] Ph1 done", $time);

        // Phase 2: phase_align
        phase = 2;
        force u_cal_sign.fb_sample = 1; #80000;
        $display("[%0t] Ph2 bias1: dly=%0d", $time, delay_code);
        force u_cal_sign.fb_sample = 0; #80000;
        $display("[%0t] Ph2 bias0: dly=%0d", $time, delay_code);
        release u_cal_sign.fb_sample; #10000;
        $display("[%0t] Ph2 done: dly=%0d", $time, delay_code);

        // ---- Phase 3: sign=0, dtc_code↑ × 20000 ----
        phase = 3; gain_base_v = 512; sign_dtc = 0; dtc_code_v = 200;
        $display("[%0t] Ph3: sign=0, code↑", $time);
        for (t = 0; t < 20000; t = t + 1) begin
            @(posedge sys_clk);
            if (dtc_code_v >= 300) dtc_code_v <= 200;
            else dtc_code_v <= dtc_code_v + 1;
        end
        $display("[%0t] Ph3: gain=%0d (expect <<512)", $time, gain_corrected);

        // ---- Phase 4: sign=1, dtc_code↑ × 20000 ----
        phase = 4; gain_base_v = 512; sign_dtc = 1; dtc_code_v = 200;
        $display("[%0t] Ph4: sign=1, code↑", $time);
        for (t = 0; t < 20000; t = t + 1) begin
            @(posedge sys_clk);
            if (dtc_code_v >= 300) dtc_code_v <= 200;
            else dtc_code_v <= dtc_code_v + 1;
        end
        $display("[%0t] Ph4: gain=%0d (expect >>512)", $time, gain_corrected);

        // ---- Phase 5: sign=0, dtc_code↓ × 20000 ----
        phase = 5; gain_base_v = 512; sign_dtc = 0; dtc_code_v = 300;
        $display("[%0t] Ph5: sign=0, code↓", $time);
        for (t = 0; t < 20000; t = t + 1) begin
            @(posedge sys_clk);
            if (dtc_code_v <= 100) dtc_code_v <= 300;
            else dtc_code_v <= dtc_code_v - 1;
        end
        $display("[%0t] Ph5: gain=%0d (expect >>512)", $time, gain_corrected);

        // ---- Phase 6: sign=1, dtc_code↓ × 20000 ----
        phase = 6; gain_base_v = 512; sign_dtc = 1; dtc_code_v = 300;
        $display("[%0t] Ph6: sign=1, code↓", $time);
        for (t = 0; t < 20000; t = t + 1) begin
            @(posedge sys_clk);
            if (dtc_code_v <= 100) dtc_code_v <= 300;
            else dtc_code_v <= dtc_code_v - 1;
        end
        $display("[%0t] Ph6: gain=%0d (expect <<512)", $time, gain_corrected);

        $display("=== Done ===");
        $finish;
    end

    always #100000 begin
        if (phase >= 2)
            $display("[%0t] ph=%0d dly=%0d gain=%0d sign=%b",
                     $time, phase, delay_code, gain_corrected, sign_dtc);
    end

endmodule
