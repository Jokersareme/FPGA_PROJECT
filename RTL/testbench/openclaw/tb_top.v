`timescale 1ns / 1ps
module tb_top;
    parameter SYS_CLK_PERIOD = 8.0;
    reg sys_clk_p = 0; reg sys_clk_n = 0; reg sys_rst;
    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;

    fpga_ssc_pll_top u_dut (
        .sys_clk_p(sys_clk_p), .sys_clk_n(sys_clk_n), .sys_rst(sys_rst),
        .sma_ref_p(sma_ref_p), .sma_ref_n(sma_ref_n),
        .sma_dtc_p(sma_dtc_p), .sma_dtc_n(sma_dtc_n));

    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;

    initial begin
        sys_rst = 0; #1 sys_rst = 1; #100 sys_rst = 0;
    end

    initial begin
        $dumpfile("tb_top_jitter.vcd");
        $dumpvars(0, tb_top);
    end

    // Jitter analysis
    reg [63:0] rmin=1000000000, rmax=0, rtot=0, rcnt=0, redge=0, rlast=0;
    reg [63:0] dmin=1000000000, dmax=0, dtot=0, dcnt=0, dedge=0, dlast=0;

    always @(posedge u_dut.div_out_raw) begin
        if (rlast != 0 && redge > 100 && redge <= 200) begin
            rcnt <= rcnt + 1; rtot <= rtot + ($time - rlast);
            if ($time - rlast < rmin) rmin <= $time - rlast;
            if ($time - rlast > rmax) rmax <= $time - rlast;
        end
        rlast <= $time; redge <= redge + 1;
    end

    always @(posedge sma_ref_p) begin
        if (dlast != 0 && dedge > 100 && dedge <= 200) begin
            dcnt <= dcnt + 1; dtot <= dtot + ($time - dlast);
            if ($time - dlast < dmin) dmin <= $time - dlast;
            if ($time - dlast > dmax) dmax <= $time - dlast;
        end
        dlast <= $time; dedge <= dedge + 1;
    end

    initial begin
        #1800000;
        $display("");
        $display("=== Jitter Analysis (100 periods) ===");
        $display("--- Reference (div_out_raw) ---");
        if (rcnt > 0) begin
            $display("  Avg: %0d ps (%.1f ns)", rtot/rcnt, (rtot/rcnt)/1000.0);
            $display("  Min: %0d  Max: %0d  Jitter: %0d ps (%.1f%%)", rmin, rmax, rmax-rmin, (rmax-rmin)*100.0/(rtot/rcnt));
        end
        $display("--- DTC compensated (sma_ref_p) ---");
        if (dcnt > 0) begin
            $display("  Avg: %0d ps (%.1f ns)", dtot/dcnt, (dtot/dcnt)/1000.0);
            $display("  Min: %0d  Max: %0d  Jitter: %0d ps (%.1f%%)", dmin, dmax, dmax-dmin, (dmax-dmin)*100.0/(dtot/dcnt));
        end
        $display("Expected: 625MHz / 71.208 = 8.78MHz");
        $finish;
    end
endmodule