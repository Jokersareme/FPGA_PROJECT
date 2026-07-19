`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: tb_lut_dtc_postsim
// Description: POST-SYNTHESIS gate-level simulation for lut_dtc
//
// 关键: 用 $sdf_annotate 标注真实延迟, 能看到 CARRY8 的 15ps/tap 延迟
//
// 测量方法:
//   din 翻转 → 测 dout 翻转时刻 → 得到实际延迟
//   扫描 code=0~511, 画出 code→delay 曲线
//////////////////////////////////////////////////////////////////////////////////
module tb_lut_dtc_postsim;

    reg         sys_clk = 0;
    reg         rst_n = 0;
    reg         din = 0;
    reg  [8:0]  code = 0;
    reg         cal_mode = 0;
    reg         dtc_sel = 0;
    wire        dout;
    wire [8:0]  cal_result;
    wire        cal_valid;

    // 门级DUT (综合后网表)
    lut_dtc DUT (
        .sys_clk    (sys_clk),
        .rst_n      (rst_n),
        .din        (din),
        .code       (code),
        .cal_mode   (cal_mode),
        .dtc_sel    (dtc_sel),
        .dout       (dout),
        .cal_result (cal_result),
        .cal_valid  (cal_valid)
    );

    // SDF 延迟标注 (关键!)
    initial begin
        $sdf_annotate("lut_dtc_synth.sdf", DUT);
    end

    // 时钟
    always #5 sys_clk = ~sys_clk;  // 100MHz

    // 延迟测量变量
    real        delay_ps;
    real        delay_arr [0:15];  // 存储16个code点的延迟
    integer     i;
    integer     sample_idx;
    reg         prev_dout;
    time        din_time;
    time        dout_time;

    // 监控 dout 翻转, 记录时刻
    always @(dout) begin
        if (dout !== 1'bx && dout !== 1'bz) begin
            dout_time = $time;
            if (din_time > 0) begin
                delay_ps = (dout_time - din_time) / 1000.0;
                // 只记录第一个翻转
            end
        end
    end

    // 仿真流程
    initial begin
        // 初始化
        rst_n = 0;
        din = 0;
        code = 0;
        dtc_sel = 0;
        cal_mode = 0;
        sample_idx = 0;
        din_time = 0;
        prev_dout = 0;

        #100 rst_n = 1;
        #50;

        // ============================================================
        // Test: Path A 延迟扫描 (code=0,32,64,...,480)
        // ============================================================
        $display("========================================");
        $display("  POST-SIM: Path A (dtc_sel=0) delay scan");
        $display("========================================");
        $display("  code   |  delay(ps)  |  dout");
        $display("  -------+-------------+------");

        dtc_sel = 0;
        for (i = 0; i <= 15; i = i + 1) begin
            code = i * 32;          // 0,32,64,...,480
            din = 0;
            #200;                    // 等待稳定
            din_time = $time;
            din = 1;                 // din 上升沿
            #500;                    // 等待 dout 响应
            delay_arr[i] = delay_ps;
            $display("  %4d   |  %8.1f  |  %b", code, delay_ps, dout);
            din = 0;
            #100;
        end

        // ============================================================
        // Test: Path B 延迟扫描
        // ============================================================
        $display("========================================");
        $display("  POST-SIM: Path B (dtc_sel=1) delay scan");
        $display("========================================");
        $display("  code   |  delay(ps)  |  dout");
        $display("  -------+-------------+------");

        dtc_sel = 1;
        for (i = 0; i <= 15; i = i + 1) begin
            code = i * 32;
            din = 0;
            #200;
            din_time = $time;
            din = 1;
            #500;
            delay_arr[i] = delay_ps;
            $display("  %4d   |  %8.1f  |  %b", code, delay_ps, dout);
            din = 0;
            #100;
        end

        // ============================================================
        // Test: 段边界精细扫描 (Path A, code=60~68)
        // ============================================================
        $display("========================================");
        $display("  POST-SIM: Path A segment boundary (code=60~68)");
        $display("========================================");
        dtc_sel = 0;
        for (i = 60; i <= 68; i = i + 1) begin
            code = i;
            din = 0;
            #200;
            din_time = $time;
            din = 1;
            #500;
            $display("  code=%2d  delay=%8.1f ps  dout=%b", i, delay_ps, dout);
            din = 0;
            #100;
        end

        // ============================================================
        // Test: dtc_sel 切换
        // ============================================================
        $display("========================================");
        $display("  POST-SIM: dtc_sel dynamic switch");
        $display("========================================");
        code = 256;
        din = 0;
        #200;
        din_time = $time;
        din = 1;
        #500;
        $display("  dtc_sel=0: delay=%8.1f ps", delay_ps);
        dtc_sel = 1;
        #200;
        din_time = $time;
        din = 0;
        #500;
        din_time = $time;
        din = 1;
        #500;
        $display("  dtc_sel=1: delay=%8.1f ps", delay_ps);

        $display("========================================");
        $display("  POST-SIM COMPLETE");
        $display("========================================");
        $finish;
    end

    // 超时保护
    initial begin
        #1000000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
