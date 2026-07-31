`timescale 1ns / 1ps

module tb_top;
    parameter SYS_CLK_PERIOD = 8.0;  // 125MHz

    reg sys_clk_p = 0;
    reg sys_clk_n = 0;
    reg sys_clk_div = 0;
    reg sys_rst;

    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;

    fpga_ssc_pll_top u_dut (
        .sys_clk_p (sys_clk_p),
        .sys_clk_n (sys_clk_n),
        .sys_rst   (sys_rst),
        .sma_ref_p (sma_ref_p),
        .sma_ref_n (sma_ref_n),
        .sma_dtc_p (sma_dtc_p),
        .sma_dtc_n (sma_dtc_n)
    );

    // 125MHz differential clock
    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;
    always #(1.6*(71+213/1024)/2) sys_clk_div = ~sys_clk_div;

    // Reset sequence
    initial begin
        sys_rst = 0;
        #1;
        sys_rst = 1;
        #100;
        sys_rst = 0;
    end

    // VCD dump
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

    // ============================================================
    // Jitter analysis: measure period of div_out_raw and sma_ref_p
    // ============================================================
    reg [63:0] rmin = 1000000000, rmax = 0, rtot = 0, rcnt = 0, redge = 0, rlast = 0;
    reg [63:0] dmin = 1000000000, dmax = 0, dtot = 0, dcnt = 0, dedge = 0, dlast = 0;

    always @(posedge u_dut.div_out_raw) begin
        if (rlast != 0 && redge > 100 && redge <= 200) begin
            rcnt <= rcnt + 1;
            rtot <= rtot + ($time - rlast);
            if ($time - rlast < rmin) rmin <= $time - rlast;
            if ($time - rlast > rmax) rmax <= $time - rlast;
        end
        rlast <= $time;
        redge <= redge + 1;
    end

    always @(posedge sma_ref_p) begin
        if (dlast != 0 && dedge > 100 && dedge <= 200) begin
            dcnt <= dcnt + 1;
            dtot <= dtot + ($time - dlast);
            if ($time - dlast < dmin) dmin <= $time - dlast;
            if ($time - dlast > dmax) dmax <= $time - dlast;
        end
        dlast <= $time;
        dedge <= dedge + 1;
    end

    // Simulation timeout and report
    initial begin
        #18000;
        $display("");
        $display("============================================================");
        $display("=           SSC PLL + DTC Simulation Report                =");
        $display("============================================================");
        $display("--- Reference (div_out_raw) ---");
        if (rcnt > 0) begin
            $display("  Avg Period: %0d ns (%.3f us)", rtot/rcnt, (rtot/rcnt)/1000.0);
            $display("  Min: %0d ns  Max: %0d ns  Jitter: %0d ns (%.2f%%)", rmin, rmax, rmax-rmin, (rmax-rmin)*100.0/(rtot/rcnt));
        end else begin
            $display("  No valid edges captured.");
        end
        $display("--- DTC Compensated (sma_ref_p) ---");
        if (dcnt > 0) begin
            $display("  Avg Period: %0d ns (%.3f us)", dtot/dcnt, (dtot/dcnt)/1000.0);
            $display("  Min: %0d ns  Max: %0d ns  Jitter: %0d ns (%.2f%%)", dmin, dmax, dmax-dmin, (dmax-dmin)*100.0/(dtot/dcnt));
        end else begin
            $display("  No valid edges captured.");
        end
        $display("============================================================");
        $display("Expected: 625MHz / 71.208 = 8.78MHz => ~114ns period");
        $display("PLL locked: %b", u_dut.locked_pll);
        $display("Calibration done: %b", u_dut.cal_done);
        $display("============================================================");
        $finish;
    end

    // Early watchdog: if nothing happens for too long, abort
    initial begin
        #50000;
        $display("ERROR: Simulation timeout (5ms). Something is stuck.");
        $finish;
    end

endmodule
