`timescale 1ns / 1ps
//
// 干净的一阶自动校准测试平台 - v2
// - 使用 VIO 仿真模型正常驱动，无 force
// - 带延迟的 DTC 模型 (code * 10ps)
// - 校准后 dtc_code 统计
//
module tb_auto_full;
    parameter SYS_CLK_PERIOD = 8.0;  // 125MHz

    reg sys_clk_p = 0;
    reg sys_clk_n = 0;
    reg sys_rst;
    wire sma_ref_p, sma_ref_n;
    wire sma_dtc_p, sma_dtc_n;

    // DUT
    fpga_ssc_pll_top u_dut (
        .sys_clk_p  (sys_clk_p),
        .sys_clk_n  (sys_clk_n),
        .sys_rst    (sys_rst),
        .sma_ref_p  (sma_ref_p),
        .sma_ref_n  (sma_ref_n),
        .sma_dtc_p  (sma_dtc_p),
        .sma_dtc_n  (sma_dtc_n)
    );

    // 时钟
    always #(SYS_CLK_PERIOD / 2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD / 2) sys_clk_n = ~sys_clk_n;

    // 复位: sys_rst=1 → sys_rst_n=0 (复位)
    initial begin
        sys_rst = 1;
        #103 sys_rst = 0;
    end

    // VCD dump
    initial begin
        $dumpfile("tb_top_auto_full.vcd");
        $dumpvars(0, tb_auto_full);
    end

    // ================================================================
    // 校准监测 + 后校准统计
    // ================================================================
    reg [8:0] dtc_code_max = 0;
    reg [8:0] dtc_code_min = 9'd511;
    reg [31:0] dtc_code_sum = 0;
    reg [31:0] dtc_code_cnt = 0;
    reg dtc_code_start = 0;

    // 校准完成后开始采集 dtc_code
    always @(posedge u_dut.div_out_raw_g) begin
        if (u_dut.cal_done) begin
            dtc_code_start <= 1;
        end
        if (dtc_code_start) begin
            dtc_code_cnt <= dtc_code_cnt + 1;
            dtc_code_sum <= dtc_code_sum + u_dut.dtc_code;
            if (u_dut.dtc_code > dtc_code_max) dtc_code_max <= u_dut.dtc_code;
            if (u_dut.dtc_code < dtc_code_min) dtc_code_min <= u_dut.dtc_code;
        end
    end

    initial begin
        #200;

        // 等待校准开始
        wait(u_dut.u_cal.cal_mode);
        $display("@%0t: Calibration STARTED", $time);

        // 等待校准完成
        wait(u_dut.u_cal.cal_done);
        @(posedge u_dut.sys_clk_g);
        $display("@%0t: Calibration DONE", $time);
        $display("  dtc_gain_cal = %0d", u_dut.dtc_gain_cal);
        $display("  tdc_min = %0d, tdc_max = %0d",
            u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max);
        $display("  K_CONST = %0d", u_dut.u_cal.K_CONST);

        // 等 dtc_code 采集 200 个样本
        #50000;

        $display("@%0t: Post-calibration dtc_code stats (samples=%0d):", $time, dtc_code_cnt);
        $display("  min = %0d, max = %0d, avg = %0d",
            dtc_code_min, dtc_code_max,
            dtc_code_cnt ? (dtc_code_sum / dtc_code_cnt) : 0);
        $display("  range = %0d", dtc_code_max - dtc_code_min);

        // 显示最后的增益和 code
        $display("@%0t: dtc_gain_muxed = %0d, dtc_offset = %0d, dtc_en = %0b",
            $time, u_dut.dtc_gain_muxed, u_dut.dtc_offset, u_dut.dtc_en);
        $display("@%0t: cal_mode = %0b, cal_auto_en = %0b",
            $time, u_dut.cal_mode_sel, u_dut.cal_auto_en);

        #70000;
        $display("@%0t: === Simulation Complete ===", $time);
        $finish;
    end

endmodule
