`timescale 1ns / 1ps
// ============================================================================
// tb_force_clk.v — 顶层仿真，用 testbench 生成理想时钟绕过 PLL/分频器挂起
// ============================================================================
// 控制信号:
//   cal_auto_en=1, order_sel=1 (3阶), clk_sel_0=2 (bypass PLL mux)
// ============================================================================
module tb_force_clk;
    parameter SYS_CLK_PERIOD = 8.0;     // 125MHz
    parameter VCO_PERIOD     = 1.6;     // 625MHz
    parameter FOUT_DIV       = 71;      // 分频比 = 4*17+3
    parameter FOUT_PERIOD    = VCO_PERIOD * FOUT_DIV;  // 113.6ns

    reg sys_clk_p = 0, sys_clk_n = 0;
    reg sys_rst;
    reg dvco_clk = 0;      // 625MHz VCO 时钟
    reg fout_clk = 0;      // ~8.8MHz 理想 Fout

    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;

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

    // --- 关键: force 理想时钟替代 PLL/分频器 ---
    initial begin
        #104;
        force u_dut.locked_pll = 1'b1;
    end
    // dvco_clk = 625MHz → 通过 PLL 反馈路径注入 clk_out_pll
    always begin : f_dvco
        @(dvco_clk);
        if (dvco_clk) force u_dut.clk_fb_pll_raw = 1'b1;
        else          force u_dut.clk_fb_pll_raw = 1'b0;
    end
    // fout_clk = 8.8MHz → 替代 fracn 输出
    always begin : f_fout
        @(fout_clk);
        if (fout_clk) begin
            force u_dut.div_out_raw_g = 1'b1;
            force u_dut.div_out_raw = 1'b1;
            force u_dut.u_ssc_ctrl.clk = 1'b1;
        end else begin
            force u_dut.div_out_raw_g = 1'b0;
            force u_dut.div_out_raw = 1'b0;
            force u_dut.u_ssc_ctrl.clk = 1'b0;
        end
    end

    // --- VCD ---
    initial begin
        $dumpfile("tb_force_clk.vcd");
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
        $dumpvars(1, u_dut.u_cal.state, u_dut.u_cal.dtc_code_cal);
        $dumpvars(1, u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max, u_dut.u_cal.cal_result);
        $dumpvars(1, u_dut.u_cal.wait_cnt, u_dut.u_cal.cal_mode);
        $dumpvars(1, u_dut.u_lut_dtc_top.cal_valid, u_dut.u_lut_dtc_top.tdc_valid);
        $dumpvars(1, u_dut.u_lut_dtc_top.din_rise, u_dut.u_lut_dtc_top.tdc_measuring);
        $dumpvars(1, u_dut.u_lut_dtc_top.tdc_counter, u_dut.u_lut_dtc_top.cal_mode_m2);
        $dumpvars(1, u_dut.u_lut_dtc_top.din_delayed);
        $dumpvars(1, dvco_clk, fout_clk);
    end

    // --- 主控 ---
    initial begin
        #500;  // 等启动
        $display("@%0t: dvco=%0dMHz fout=%0dMHz",
            $time, 1000/VCO_PERIOD, 1000/FOUT_PERIOD);

        wait(u_dut.u_cal.cal_mode);
        $display("@%0t: Cal START", $time);

        wait(u_dut.u_cal.cal_done);
        $display("@%0t: Cal DONE gain=%0d gain_muxed=%0d", $time,
            u_dut.dtc_gain_cal, u_dut.dtc_gain_muxed);
        $display("  tdc_min=%0d tdc_max=%0d cal_result=%0d",
            u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max, u_dut.u_cal.cal_result);

        #20000;
        $display("@%0t: DONE", $time);
        $finish;
    end

    // --- 超时保护 ---
    initial begin
        #100_000_000;  // 100us
        $display("@%0t: TIMEOUT", $time);
        $finish;
    end

endmodule
