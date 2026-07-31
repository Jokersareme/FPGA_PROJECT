`timescale 1ns / 1ps
module tb_quick_3rd;
    parameter SYS_CLK_PERIOD = 8.0;
    reg sys_clk_p = 0; reg sys_clk_n = 0; reg sys_rst;
	reg ideal_clk = 0;
    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;

    fpga_ssc_pll_top u_dut (
        .sys_clk_p(sys_clk_p), .sys_clk_n(sys_clk_n), .sys_rst(sys_rst),
        .sma_ref_p(sma_ref_p), .sma_ref_n(sma_ref_n),
        .sma_dtc_p(sma_dtc_p), .sma_dtc_n(sma_dtc_n));

    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;
    always #(SYS_CLK_PERIOD*100.25/2) ideal_clk = ~ideal_clk;

    initial begin
        sys_rst = 1;
        #103 sys_rst = 0;
        #80000 sys_rst = 1;
        #1000 sys_rst = 0;
        #80000 sys_rst = 1;
        #1000 sys_rst = 0;
        #80000;
        $display("@%0t: DONE", $time);
        $finish;
    end

    initial begin
        $dumpfile("tb_quick_3rd.vcd");
        $dumpvars(0, tb_quick_3rd);
    end

    initial begin
        #200;
        forever begin
            #5000;
            $display("[%0t] sys_rst=%b state=%0d cal_mode=%b cal_done=%b cal_start=%b gain=%0d wait_cnt=%0d",
                $time, sys_rst,
                u_dut.u_cal.state, u_dut.u_cal.cal_mode,
                u_dut.cal_done, u_dut.u_vio_cal.cal_start_r,
                u_dut.dtc_gain_cal, u_dut.u_cal.wait_cnt);
        end
    end

    initial begin
        #250000;
        $display("@%0t: TIMEOUT", $time);
        $finish;
    end
endmodule
