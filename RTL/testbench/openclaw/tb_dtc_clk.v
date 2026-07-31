`timescale 1ns / 1ps
// ============================================================================
// tb_dtc_clk.v — 顶层仿真，用 testbench 生成理想时钟
// dvco_clk / fout_clk 由 xilinx_sim.v 的 PLL 模型直接输出
// 不修改任何 RTL 源码，不 force
// ============================================================================
module tb_dtc_clk;
    parameter SYS_CLK_PERIOD = 8.0;     // 125MHz
    parameter VCO_PERIOD     = 1.6;     // 625MHz
    parameter FOUT_DIV       = 71;      // 分频比 = 4*17+3
    parameter FOUT_PERIOD    = VCO_PERIOD * FOUT_DIV;  // 113.6ns

    reg sys_clk_p = 0, sys_clk_n = 0;
    reg sys_rst;

    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;

    reg dvco_clk = 0;      // 625MHz VCO 时钟
    reg fout_clk = 0;      // ~8.8MHz 理想 Fout

    // 通过 wire 连接到 DUT — xilinx_sim.v 中的 PLL 模型会读取这些信号
    wire dut_dvco;
    wire dut_fout;
    assign dut_dvco = dvco_clk;
    assign dut_fout = fout_clk;

    fpga_ssc_pll_top u_dut (
        .sys_clk_p(sys_clk_p), .sys_clk_n(sys_clk_n), .sys_rst(sys_rst),
        .sma_ref_p(sma_ref_p), .sma_ref_n(sma_ref_n),
        .sma_dtc_p(sma_dtc_p), .sma_dtc_n(sma_dtc_n));

    // --- 时钟生成 ---
    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;
    always #(VCO_PERIOD/2)     dvco_clk = ~dvco_clk;
    always #(FOUT_PERIOD/2)    fout_clk = ~fout_clk;

    // --- 复位 ---
    initial begin sys_rst = 1; #103 sys_rst = 0; end
    initial begin #50; force u_dut.cal_mode_sel = u_dut.cal_mode_int; end

    // --- VCD ---
    initial begin
        $dumpfile("tb_dtc_clk.vcd");
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_1);
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_2);
        $dumpvars(1, u_dut.u_fracn_div.u_mash111.e_o_3);
        $dumpvars(1, u_dut.u_fracn_div.e3_r1, u_dut.u_fracn_div.e3_r2, u_dut.u_fracn_div.e3_r3);
        $dumpvars(1, u_dut.u_fracn_div.comp_3rd);
        $dumpvars(1, u_dut.u_fracn_div.Eo, u_dut.u_fracn_div.E_combined);
        $dumpvars(1, u_dut.mash_e_combined, u_dut.mash_e_dtc);
        $dumpvars(1, u_dut.dtc_code, u_dut.dtc_code_pipe, u_dut.dtc_code_d1);
        $dumpvars(1, u_dut.dtc_gain_muxed, u_dut.dtc_gain_cal);
        $dumpvars(1, u_dut.order_sel, u_dut.cal_auto_en, u_dut.cal_done);
        $dumpvars(1, u_dut.div_out_raw_g, u_dut.div_out_dtc_g);
        $dumpvars(1, u_dut.clk_out_pll);
        $dumpvars(1, u_dut.u_cal.state, u_dut.u_cal.dtc_code_cal);
        $dumpvars(1, u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max, u_dut.u_cal.cal_result);
        $dumpvars(1, dvco_clk, fout_clk);
    end

    // --- 主控 ---
    initial begin
        #500;
        $display("@%0t: dvco=%0dMHz fout=%0dMHz",
            $time, 1000/VCO_PERIOD, 1000/FOUT_PERIOD);
        wait(u_dut.u_cal.cal_mode);
        $display("@%0t: Cal START", $time);
        wait(u_dut.u_cal.cal_done);
        $display("@%0t: Cal DONE gain=%0d gain_muxed=%0d", $time,
            u_dut.dtc_gain_cal, u_dut.dtc_gain_muxed);
        $display("  tdc_min=%0d tdc_max=%0d", u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max);
        #20000;
        $display("@%0t: DONE", $time);
        $finish;
    end

    initial begin #100_000_000; $display("@%0t: TIMEOUT", $time); $finish; end
endmodule
