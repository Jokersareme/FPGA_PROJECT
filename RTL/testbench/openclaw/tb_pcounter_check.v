`timescale 1ns / 1ps
module tb_auto_full;
    parameter SYS_CLK_PERIOD = 8.0;
    reg sys_clk_p = 0; reg sys_clk_n = 0; reg sys_rst;
    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;

    fpga_ssc_pll_top u_dut (
        .sys_clk_p(sys_clk_p), .sys_clk_n(sys_clk_n), .sys_rst(sys_rst),
        .sma_ref_p(sma_ref_p), .sma_ref_n(sma_ref_n),
        .sma_dtc_p(sma_dtc_p), .sma_dtc_n(sma_dtc_n));

    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;

    initial begin sys_rst = 1; #103 sys_rst = 0; end
    initial begin force u_dut.cal_mode_sel = u_dut.cal_mode_int; end

    initial begin
        #200;
        wait(u_dut.u_cal.cal_mode);
        $display("@%0t: Cal START", $time);
        wait(u_dut.u_cal.cal_done);
        $display("@%0t: Cal DONE gain=%0d code=%0d", $time,
            u_dut.dtc_gain_cal, u_dut.dtc_code);
        #5000;
        $display("@%0t: DONE", $time);
        $finish;
    end
endmodule
