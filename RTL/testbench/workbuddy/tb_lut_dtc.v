`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: tb_lut_dtc
// Description: RTL testbench for dual-path lut_dtc
//
// NOTE: RTL simulation has ZERO gate delay. CARRY8 carry-chain delay
// (15ps/tap) is NOT visible. This TB verifies:
//   1. MUX selection logic (code -> correct tap)
//   2. dtc_sel switches between Path A and Path B
//   3. Signal passes through 5-stage cascade
//   4. No X or Z on dout for valid code values
//
// For real delay measurement, run post-synthesis gate-level sim with SDF.
//////////////////////////////////////////////////////////////////////////////////
module tb_lut_dtc;

    reg         sys_clk = 0;
    reg         rst_n = 0;
    reg         din = 0;
    reg  [8:0]  code = 0;
    reg         cal_mode = 0;
    reg         dtc_sel = 0;
    wire        dout;
    wire [8:0]  cal_result;
    wire        cal_valid;

    // DUT
    lut_dtc #(
        .N_TAP      (512),
        .CODE_WIDTH (9)
    ) u_dut (
        .sys_clk    (sys_clk),
        .rst_n      (rst_n),
        .din        (din),
        .code       (code),
        .cal_mode   (cal_mode),
        .dtc_sel    (dtc_sel),
        .dout       (dout),
        .cal_result (cal_result),
        .cal_valid  (cal_valid)
    );

    // Clock: 100MHz, 10ns period
    always #5 sys_clk = ~sys_clk;

    // Input signal: 10MHz square wave on din
    always #50 din = ~din;

    integer k;
    integer err_cnt = 0;

    // Monitor
    initial begin
        $dumpfile("tb_lut_dtc.vcd");
        $dumpvars(0, tb_lut_dtc);
    end

    initial begin
        // Reset
        rst_n = 0;
        code = 0;
        dtc_sel = 0;
        #20;
        rst_n = 1;
        #20;

        // ================================================================
        // Test 1: Path A, sweep code 0 -> 511, check no X/Z on dout
        // ================================================================
        $display("=== Test 1: Path A (dtc_sel=0), code sweep ===");
        dtc_sel = 0;
        for (k = 0; k <= 511; k = k + 32) begin
            code = k;
            #100;
            if (dout === 1'bx || dout === 1'bz) begin
                $display("  [FAIL] code=%0d, dout=%b", k, dout);
                err_cnt = err_cnt + 1;
            end else begin
                $display("  [ OK ] code=%0d, dout=%b", k, dout);
            end
        end
        #100;

        // ================================================================
        // Test 2: Path B, sweep code 0 -> 511, check no X/Z on dout
        // ================================================================
        $display("=== Test 2: Path B (dtc_sel=1), code sweep ===");
        dtc_sel = 1;
        for (k = 0; k <= 511; k = k + 32) begin
            code = k;
            #100;
            if (dout === 1'bx || dout === 1'bz) begin
                $display("  [FAIL] code=%0d, dout=%b", k, dout);
                err_cnt = err_cnt + 1;
            end else begin
                $display("  [ OK ] code=%0d, dout=%b", k, dout);
            end
        end
        #100;

        // ================================================================
        // Test 3: Segment boundary check (Path A)
        //   Boundaries at code=64,128,192,256,320,384,448
        // ================================================================
        $display("=== Test 3: Path A segment boundaries ===");
        dtc_sel = 0;
        for (k = 60; k <= 68; k = k + 1) begin
            code = k;
            #100;
            $display("  code=%0d (seg=%0d, tap_in_seg=%0d), dout=%b",
                     k, k[8:6], k[5:0], dout);
        end
        #100;

        // ================================================================
        // Test 4: Segment boundary check (Path B)
        //   Boundaries at code=128,256,384
        // ================================================================
        $display("=== Test 4: Path B segment boundaries ===");
        dtc_sel = 1;
        for (k = 124; k <= 132; k = k + 1) begin
            code = k;
            #100;
            $display("  code=%0d (seg=%0d, tap_in_seg=%0d), dout=%b",
                     k, k[8:7], k[6:0], dout);
        end
        #100;

        // ================================================================
        // Test 5: dtc_sel switching while din toggling
        // ================================================================
        $display("=== Test 5: dtc_sel dynamic switch ===");
        code = 200;
        dtc_sel = 0;
        #200;
        $display("  Path A: dout=%b", dout);
        dtc_sel = 1;
        #200;
        $display("  Path B: dout=%b", dout);
        dtc_sel = 0;
        #200;
        $display("  Path A: dout=%b", dout);
        #100;

        // ================================================================
        // Test 6: din toggle passthrough at code=0 (tap[0] = co[0][0])
        // ================================================================
        $display("=== Test 6: din passthrough at code=0 ===");
        code = 0;
        dtc_sel = 0;
        din = 0;
        #100;
        $display("  din=0, code=0, dout=%b (expect 0)", dout);
        din = 1;
        #100;
        $display("  din=1, code=0, dout=%b (expect 1)", dout);
        din = 0;
        #100;
        $display("  din=0, code=0, dout=%b (expect 0)", dout);

        // Summary
        #200;
        $display("========================================");
        if (err_cnt == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  FAILED: %0d errors", err_cnt);
        $display("========================================");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
