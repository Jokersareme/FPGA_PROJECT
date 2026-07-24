`timescale 1ns / 1ps
// =============================================================================
// tb_comp_standalone.v — 三阶补偿公式验证
// 直接注入 MASH 误差模式, 避开 PLL/TDC/校准器复杂性
// =============================================================================
module tb_comp_standalone;

    reg clk;
    reg rst_n;

    // ---- DTC Comp 接口 ----
    wire [12:0] e_in;          // 输入给 dtc_comp 的误差
    reg  [9:0]  dtc_gain;
    reg         dtc_en;
    reg  [8:0]  dtc_offset;
    reg         order_sel;
    wire [8:0]  dtc_code;

    // ---- fractionaln 内部信号 (直接取引线) ----
    reg  [9:0]  e3_in;         // 模拟 e3 (第3级 EFM 误差)
    reg  [9:0]  e1_in;         // 模拟 e1

    // ---- 管道寄存器: 模拟 fractionaln 行为 ----
    reg  [9:0]  e3_r1 = 0, e3_r2 = 0, e3_r3 = 0;
    reg  [9:0]  e1_r  = 0;
    wire [12:0] comp_3rd;      // e3[n] - 2*e3[n-1] + e3[n-2]
    reg  [12:0] E_combined;

    // --- 补偿计算 (直接复制 fractionaln.v 公式) ---
    assign comp_3rd = $signed({2'b0, e3_r1})
                    - $signed({1'b0, e3_r2, 1'b0})
                    + $signed({2'b0, e3_r3});

    // --- 选择器: 同 fpga_ssc_pll_top.v ---
    assign e_in = order_sel ? $signed(E_combined) : $signed({3'b0, e1_r});

    // --- 时钟 (参考 Fout 频率 ~9.6MHz) ---
    always #52 clk = ~clk;   // ~9.6MHz

    // --- 初始化 ---
    initial begin
        clk = 0; rst_n = 0;
        dtc_gain = 160; dtc_en = 1; dtc_offset = 0; order_sel = 1;
        e3_in = 0; e1_in = 0;
        #100 rst_n = 1;
        #104;  // 等一个时钟
        run_test;
        #5000;
        $display("=== DONE ===");
        $finish;
    end

    // --- 流水线 (同 fractionaln negedge 行为) ---
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            e3_r1 <= 0; e3_r2 <= 0; e3_r3 <= 0;
            e1_r  <= 0;
            E_combined <= 0;
        end else begin
            e3_r1 <= e3_in;        // e3[n]
            e3_r2 <= e3_r1;        // e3[n-1]
            e3_r3 <= e3_r2;        // e3[n-2]
            e1_r  <= e1_in;
            E_combined <= comp_3rd;
        end
    end

    // --- DTC 补偿 (例化 dtc_comp) ---
    dtc_comp #(.WIDTH(13), .SHIFT(11), .DTC_WIDTH(9)) u_dtc (
        .clk(clk), .rst_n(rst_n),
        .e1(e_in),
        .dtc_gain(dtc_gain),
        .dtc_en(dtc_en),
        .dtc_offset(dtc_offset),
        .order_sel(order_sel),
        .dtc_code(dtc_code),
        .dtc_load()
    );

    // --- VCD ---
    initial begin
        $dumpfile("tb_comp_standalone.vcd");
        $dumpvars(1, clk, rst_n, order_sel);
        $dumpvars(1, e3_in, e3_r1, e3_r2, e3_r3);
        $dumpvars(1, comp_3rd, E_combined, e_in);
        $dumpvars(1, dtc_gain, dtc_code, dtc_offset);
    end

    // ======================================================================
    // 测试序列
    // ======================================================================
    task run_test;
        integer i;
        begin
            // =============================================
            // 测试 1: 静态偏置
            //   注入固定 e3, 观察 dtc_code = 256 (=MID)
            // =============================================
            $display("--- Test 1: Static e3=0 ---");
            e3_in = 10'd0; wait_clks(4);
            $display("  e3=(%d,%d,%d) comp_3rd=%d E=%d dtc_code=%d",
                e3_r1, e3_r2, e3_r3, comp_3rd, E_combined, dtc_code);

            // =============================================
            // 测试 2: 单脉冲
            //   e3 出现一个 512 的脉冲, 观察 comp_3rd 波形
            // =============================================
            $display("--- Test 2: Single e3=512 pulse ---");
            e3_in = 10'd512; wait_clks(1); // e3=512, 进 e3_r1
            e3_in = 10'd0;   wait_clks(4); // 等流水线排空
            $display("  e3=(%d,%d,%d) comp_3rd=%d E=%d dtc_code=%d",
                e3_r1, e3_r2, e3_r3, comp_3rd, E_combined, dtc_code);

            // =============================================
            // 测试 3: 阶跃 (保持高值)
            //   e3 从 0 变为 200, 保持 5 拍, 观察稳态
            // =============================================
            $display("--- Test 3: Step e3=0->200->0 ---");
            e3_in = 10'd200; wait_clks(5);
            $display("  e3=(%d,%d,%d) comp_3rd=%d dtc_code=%d",
                e3_r1, e3_r2, e3_r3, comp_3rd, dtc_code);
            e3_in = 10'd0; wait_clks(3);
            $display("  After clear: comp_3rd=%d dtc_code=%d",
                comp_3rd, dtc_code);

            // =============================================
            // 测试 4: 斜坡 (模拟 MASH 误差变化)
            //   验证 dc 分量被 (1-z^-1)^2 滤除
            // =============================================
            $display("--- Test 4: Ramp e3 ---");
            for (i = 0; i < 8; i = i + 1) begin
                e3_in = i * 50;
                wait_clks(1);
                $display("  e3=%3d: e3=(%3d,%3d,%3d) comp_3rd=%4d dtc_code=%3d",
                    e3_in, e3_r1, e3_r2, e3_r3, comp_3rd, dtc_code);
            end

            // =============================================
            // 测试 5: 1阶 vs 3阶对比
            //   在相同 e3 模式下交替 order_sel
            // =============================================
            $display("--- Test 5: 1st vs 3rd order ---");
            e3_in = 10'd0; e1_in = 10'd300; wait_clks(5);
            order_sel = 0;  // 1阶 (使用 e1)
            wait_clks(3);
            $display("  1阶: e1=%d dtc_code=%d", e1_r, dtc_code);
            order_sel = 1;  // 3阶
            wait_clks(3);
            $display("  3阶: e3=(%d,%d,%d) comp_3rd=%d dtc_code=%d",
                e3_r1, e3_r2, e3_r3, comp_3rd, dtc_code);

            // =============================================
            // 测试 6: 正弦调制 e3
            //   查看 dtc_code 动态范围
            // =============================================
            $display("--- Test 6: Sinusoidal e3 ---");
            wait_clks(3); // 清空流水线
            e3_in = 10'd0; wait_clks(3);
            for (i = 0; i < 32; i = i + 1) begin
                // 简化的正弦 ≈ 256 + 256*sin(2pi*i/32)
                e3_in = 256 + (i[0] ? 181 : 0) + (i[1] ? 181 : 0)
                      + (i[2] ? 128 : 0) + (i[3] ? 64 : 0);
                if (i > 16) begin
                    // 下半周期: 通过流水线延迟自然减
                    e3_in = 512 - e3_in;
                end
                wait_clks(1);
                if ((i % 4) == 0)
                    $display("  i=%2d: e3=%3d comp_3rd=%4d dtc_code=%3d",
                        i, e3_in, comp_3rd, dtc_code);
            end
        end
    endtask

    task wait_clks(input integer n);
        repeat (n) @(posedge clk);
    endtask

endmodule
