`timescale 1ns / 1ps
// ============================================================================
// tb_edge_log.v — 记录 div_out_raw_g vs div_out_dtc_g 边沿时序
// 用 $fwrite 直接写文件，不依赖 VCD
// ============================================================================
module tb_edge_log;
    parameter SYS_CLK_PERIOD = 8.0;
    parameter FOUT_PERIOD    = 113.6;  // ns

    reg sys_clk_p = 0, sys_clk_n = 0, sys_rst;

    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;

    fpga_ssc_pll_top u_dut (
        .sys_clk_p(sys_clk_p), .sys_clk_n(sys_clk_n), .sys_rst(sys_rst),
        .sma_ref_p(sma_ref_p), .sma_ref_n(sma_ref_n),
        .sma_dtc_p(sma_dtc_p), .sma_dtc_n(sma_dtc_n));

    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;

    initial begin sys_rst = 1; #103 sys_rst = 0; end
    initial begin #50; force u_dut.cal_mode_sel = u_dut.cal_mode_int; end

    // Force 理想的 dvco (625MHz) 通过 PLL 反馈
    // 利用 always @(posedge clk) 重新 force — 每次时钟上升沿更新
    reg dvco_gen = 0;
    reg fout_gen = 0;
    always #0.8 dvco_gen = ~dvco_gen;          // 625MHz
    always #(FOUT_PERIOD/2) fout_gen = ~fout_gen;  // 8.8MHz

    reg forced_dvco = 0;
    always @(posedge dvco_gen) begin
        forced_dvco <= ~forced_dvco;
        if (dvco_gen) force u_dut.clk_out_pll = 1'b1;
        else          force u_dut.clk_out_pll = 1'b0;
    end

    reg forced_fout = 0;
    always @* begin
        if (fout_gen) begin
            force u_dut.div_out_raw_g = 1'b1;
            force u_dut.div_out_raw = 1'b1;
        end else begin
            force u_dut.div_out_raw_g = 1'b0;
            force u_dut.div_out_raw = 1'b0;
        end
    end

    initial begin
        #200;
        force u_dut.locked_pll = 1'b1;
    end

    // ======================================================================
    // 边沿日志 (写入文件，替代 VCD)
    // ======================================================================
    integer fd;
    reg [8:0] prev_code = 0;
    reg prev_raw = 0, prev_dtc = 0;
    reg first = 1;

    initial begin
        fd = $fopen("edge_log.txt", "w");
        $fwrite(fd, "# edge_log: div_out_raw_g / div_out_dtc_g edge timing\n");
        $fwrite(fd, "# format: time(ps) signal value dtc_code\n");
        $fdisplay(fd, "# dvco=625MHz fout~=%.1fMHz", 1000.0/FOUT_PERIOD);
    end

    // 监测 raw_g 边沿
    always @(u_dut.div_out_raw_g) begin
        if (!$time < 200) begin end
        else begin
            $fwrite(fd, "%0d raw %b code=%0d\n",
                $time, u_dut.div_out_raw_g, u_dut.dtc_code_pipe);
        end
    end

    // 监测 dtc_g 边沿
    always @(u_dut.div_out_dtc_g) begin
        if (!$time < 200) begin end
        else begin
            $fwrite(fd, "%0d dtc %b code=%0d\n",
                $time, u_dut.div_out_dtc_g, u_dut.dtc_code_pipe);
        end
    end

    // 监测 dtc_code 变化
    always @(u_dut.dtc_code) begin
        $fwrite(fd, "%0d code %0d\n", $time, u_dut.dtc_code);
    end

    // ======================================================================
    // 主控
    // ======================================================================
    initial begin
        wait(u_dut.locked_pll);
        $display("@%0t: LOCKED, waiting for cal...", $time);
        wait(u_dut.u_cal.cal_mode);
        $display("@%0t: Cal START", $time);
        wait(u_dut.u_cal.cal_done);
        $display("@%0t: Cal DONE gain=%0d", $time, u_dut.dtc_gain_cal);
        $display("  tdc_min=%0d tdc_max=%0d", u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max);

        // 记录 10us 的数据
        repeat (88) @(posedge u_dut.div_out_raw_g);  // ~10us at 8.8MHz

        $fclose(fd);
        $display("@%0t: DONE, edge_log.txt written", $time);
        $finish;
    end

    initial begin #50_000_000; $display("TIMEOUT"); $finish; end
endmodule
