`timescale 1ns / 1ps
module tb_comp_check;
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
    initial begin #50; force u_dut.cal_mode_sel = u_dut.cal_mode_int; end

    initial begin
        $dumpfile("tb_comp_check.vcd");
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_1);
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_2);
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_3);
        $dumpvars(1, u_dut.u_fracn_div.e3_r1);
        $dumpvars(1, u_dut.u_fracn_div.e3_r2);
        $dumpvars(1, u_dut.u_fracn_div.e3_r3);
        $dumpvars(1, u_dut.u_fracn_div.comp_3rd);
        $dumpvars(1, u_dut.mash_e_combined);
        $dumpvars(1, u_dut.mash_e_dtc);
        $dumpvars(1, u_dut.dtc_code);
        $dumpvars(1, u_dut.dtc_code_pipe);
        $dumpvars(1, u_dut.dtc_code_d1);
        $dumpvars(1, u_dut.dtc_gain_muxed);
        $dumpvars(1, u_dut.dtc_gain_cal);
        $dumpvars(1, u_dut.dtc_offset);
        $dumpvars(1, u_dut.order_sel);
        $dumpvars(1, u_dut.cal_auto_en);
        $dumpvars(1, u_dut.cal_done);
        $dumpvars(1, u_dut.locked_pll);
        $dumpvars(1, u_dut.div_out_raw_g);
        $dumpvars(1, u_dut.div_out_dtc_g);
        $dumpvars(1, u_dut.u_cal.state);
        $dumpvars(1, u_dut.u_cal.cal_mode);
        $dumpvars(1, u_dut.u_cal.dtc_code_cal);
        $dumpvars(1, u_dut.u_cal.tdc_min);
        $dumpvars(1, u_dut.u_cal.tdc_max);
        $dumpvars(1, u_dut.u_cal.cal_result);
        $dumpvars(1, u_dut.u_fracn_div.mash_e1);
        $dumpvars(1, u_dut.u_fracn_div.mash_e2);
        $dumpvars(1, u_dut.u_fracn_div.mash_e3);
        $dumpvars(1, u_dut.u_fracn_div.Eo);
        $dumpvars(1, u_dut.u_fracn_div.E_combined);
    end

    initial begin
        #200;
        wait(u_dut.locked_pll);
        $display("@%0t: PLL LOCKED", $time);
        wait(u_dut.cal_done);
        $display("@%0t: CAL DONE gain=%0d gain_muxed=%0d order=%0d",
            $time, u_dut.dtc_gain_cal, u_dut.dtc_gain_muxed,
            u_dut.order_sel);
        #10000;
        $display("@%0t: DONE", $time);
        $finish;
    end
endmodule
