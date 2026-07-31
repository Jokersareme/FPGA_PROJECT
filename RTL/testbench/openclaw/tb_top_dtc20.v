`timescale 1ns / 1ps
module tb_top_dtc20;
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
        $dumpfile("tb_top_dtc20.vcd");
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_1);
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_2);
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_3);
        $dumpvars(1, u_dut.u_fracn_div.e3_r1, u_dut.u_fracn_div.e3_r2, u_dut.u_fracn_div.e3_r3);
        $dumpvars(1, u_dut.u_fracn_div.comp_3rd);
        $dumpvars(1, u_dut.u_fracn_div.Eo, u_dut.u_fracn_div.E_combined);
        $dumpvars(1, u_dut.mash_e_combined, u_dut.mash_e_dtc);
        $dumpvars(1, u_dut.dtc_code, u_dut.dtc_code_pipe, u_dut.dtc_code_d1);
        $dumpvars(1, u_dut.dtc_gain_muxed, u_dut.dtc_gain_cal);
        $dumpvars(1, u_dut.order_sel, u_dut.cal_auto_en, u_dut.cal_done, u_dut.locked_pll);
        $dumpvars(1, u_dut.div_out_raw_g, u_dut.div_out_dtc_g);
        $dumpvars(1, u_dut.u_cal.state, u_dut.u_cal.dtc_code_cal);
        $dumpvars(1, u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max, u_dut.u_cal.cal_result);
        $dumpvars(1, u_dut.u_cal.wait_cnt);
        $dumpvars(1, u_dut.u_cal.cal_mode);
        $dumpvars(1, u_dut.u_cal.ce_d1);
        $dumpvars(1, u_dut.u_lut_dtc_top.cal_valid);
        $dumpvars(1, u_dut.u_lut_dtc_top.tdc_valid);
        $dumpvars(1, u_dut.u_lut_dtc_top.din_rise);
        $dumpvars(1, u_dut.u_lut_dtc_top.tdc_measuring);
        $dumpvars(1, u_dut.u_lut_dtc_top.tdc_counter);
        $dumpvars(1, u_dut.u_lut_dtc_top.cal_mode_m2);
        $dumpvars(1, u_dut.u_lut_dtc_top.din_delayed);
    end

    initial begin
        #200;
        wait(u_dut.locked_pll);
        $display("@%0t: PLL LOCKED", $time);
        // 等待校准或超时(30us)
        fork
            begin: cal_wait
                wait(u_dut.u_cal.cal_mode);
                $display("@%0t: Cal START", $time);
                wait(u_dut.u_cal.cal_done);
                $display("@%0t: Cal DONE gain=%0d order=%0d tdc_mm=%0d/%0d",
                    $time, u_dut.dtc_gain_cal, u_dut.order_sel,
                    u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max);
            end
            begin: timeout
                #30000;
                $display("@%0t: Cal TIMEOUT, forcing manual mode", $time);
                disable cal_wait;
            end
        join
        $display("@%0t: Collecting data...", $time);
        #10000;
        $display("@%0t: DONE", $time);
        $finish;
    end
endmodule
