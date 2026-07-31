`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: dtc_gain_lms_cal
//
// DTC 增益 LMS 校准模块 — sign-sign LMS 算法
//
// 采用 sign-sign LMS (least-mean-square) 算法，利用 1-bit 相位符号与
// DTC 码流的方向相关性，在后台连续校准 DTC 增益。
//
// 工作原理（参考专利 EP2782255A1 Fig.5 与两篇论文的架构）：
//
//   ┌──────────┐    sign_in     ┌──────────────────┐
//   │BBPD/比较器│ ───────────→ │  XOR 相关器      │
//   └──────────┘               │ corr = s ^ d_dtc  │
//                               └────────┬─────────┘
//                                        │ corr (1-bit)
//                                        ▼
//                               ┌──────────────────┐
//                               │ 累加器（积分器）   │←─── 增益校正因子
//                               └────────┬─────────┘
//                                        │
//                                        ▼
//                               ┌──────────────────┐
//                               │ gain_corrected   │──→ dtc_comp
//                               │ = base + adjust  │
//                               └──────────────────┘
//
// 算法细节：
//   1. d_dtc = sign(dtc_code[n] - dtc_code[n-1])，码流变化方向
//   2. corr = sign_in ^ d_dtc  → 当两者不一致时，反映增益失配
//   3. 累加器对 corr 积分 → 均值反映增益误差方向与大小
//   4. 增益校正：gain_corrected = gain_base + adjust
//
// 参考：
//   [1] "A 6-9GHz DTC-based Fractional-N Sub-sampling PLL" (28nm CMOS)
//       - 后台增益校准 + 阈值失调校准，BBPD 相关法
//   [2] "A 28-nm 75-fsrms Analog Fractional-N Sampling PLL With a Highly
//       Linear DTC Incorporating Background DTC Gain Calibration"
//       (JSSC 2019, DOI: 10.1109/JSSC.2019.2899726)
//       - 模拟采样 PLL + 后台 DTC 增益校准
//   [3] EP2782255A1 - "Fractional-N frequency synthesizer using a
//       subsampling PLL and method for calibrating the same"
//       - XOR 相关器 + 累加器构成的 bang-bang 增益校准
//   [4] "Fractional-N Subsampling PLL using a DTC" (Markulic 2016, MIPRO)
//       - LMS 原理：sign(vsamp) 与 sign(ΔDTC_code) 相关
////////////////////////////////////////////////////////////////////////////////

module dtc_gain_lms_cal #(
    parameter CODE_WIDTH    = 9,       // DTC 码字位宽
    parameter GAIN_BASE_WIDTH = 10,    // 增益基础值位宽（dtc_gain 位宽）
    parameter GAIN_ADJ_WIDTH = 10,     // 增益校正量位宽（有符号）
    parameter ACCUM_WIDTH   =  20      // LMS 累加器位宽（决定收敛速度）
) (
    input  wire                       clk,           // 更新时钟（sys_clk_g）
    input  wire                       rst_n,         // 异步复位
    input  wire                       sign_in,       // 相位符号（0=ref超前=过补偿,
                                                     //             1=fb超前=欠补偿）
    input  wire  [CODE_WIDTH-1:0]     dtc_code_in,   // DTC 码字（用于提取码流方向）
    input  wire  [GAIN_BASE_WIDTH-1:0] gain_base,    // DTC 增益初始值（来自校准器
                                                     //   dtc_gain_cal 或 VIO dtc_gain）
    output reg   [GAIN_BASE_WIDTH-1:0] gain_corrected // 校准后增益 → dtc_comp
);

    // ========================================================================
    // 1. 提取 DTC 码流方向 d_dtc（升/降）
    // ========================================================================
    reg [CODE_WIDTH-1:0] dtc_code_d1;
    wire  d_dtc;   // 1 = 码字增大（需更多延迟）, 0 = 码字减小（需更少延迟）

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dtc_code_d1 <= {CODE_WIDTH{1'b0}};
        else
            dtc_code_d1 <= dtc_code_in;
    end

    assign d_dtc = (dtc_code_in > dtc_code_d1);

    // ========================================================================
    // 2. XOR 相关器
    //
    //    corr = sign_in ^ d_dtc
    //
    //    真值表：
    //   sign | d_dtc | corr | 物理含义
    //   ─────┼───────┼──────┼─────────────────────
    //    0   |  0    |  0   | ref超前 + 码字减小 → 同向 → 增益偏大（保持/减小）
    //    0   |  1    |  1   | ref超前 + 码字增大 → 反向 → 增益偏大（需减小）
    //    1   |  0    |  1   | fb超前 + 码字减小 → 反向 → 增益偏小（需增大）
    //    1   |  1    |  0   | fb超前 + 码字增大 → 同向 → 增益偏小（保持/增大）
    //
    //    corr=1 表示 sign 与 d_dtc 不一致 → 当前增益方向错误；
    //    corr=0 表示一致。
    //
    //    累加器统计 corr 的偏置：偏置方向指示增益修正方向。
    // ========================================================================
    wire corr = sign_in ^ d_dtc;

    // ========================================================================
    // 3. LMS 累加器（数字积分器 / 环路滤波器）
    //
    //    对 corr 做带符号积分：
    //      corr=1 → 累加器 -
    //      corr=0 → 累加器 +
    //
    //    高位直接作为增益校正量（带符号扩展）。
    //
    //    等效于 sign-sign LMS 更新律：
    //      adjust[n+1] = adjust[n] + mu × sign(err) × sign(Δdtc_code)
    //    其中 mu 由累加器高位截取决定时，响应速度取决于累加器位宽。
    // ========================================================================
    reg signed [ACCUM_WIDTH-1:0] lms_accum;

    wire signed [ACCUM_WIDTH-1:0] lms_step = corr
        ? $signed({{(ACCUM_WIDTH-1){1'b1}}, 1'b1})     // corr=1 → -1
        : $signed({{(ACCUM_WIDTH-1){1'b0}}, 1'b1});    // corr=0 → +1

    wire signed [ACCUM_WIDTH-1:0] accum_next = lms_accum + lms_step;

    // ========================================================================
    // 4. 增益校正输出
    //    gain_adjust = lms_accum 的高 GAIN_ADJ_WIDTH 位（有符号）
    //    gain_corrected = gain_base + gain_adjust，饱和到 [0, 2^GAIN_BASE_WIDTH-1]
    // ========================================================================
    // 取累加器高 GAIN_ADJ_WIDTH 位为增益校正量（有符号）
    // 截取位置控制环路增益（等效于 LMS 步长 mu）：
    //   取越高位 → mu 越小 → 收敛越慢、精度越高
    wire signed [GAIN_ADJ_WIDTH-1:0] gain_adjust = $signed(accum_next[ACCUM_WIDTH-1 -: GAIN_ADJ_WIDTH]);
    wire signed [GAIN_BASE_WIDTH:0] gain_sum = $signed({1'b0, gain_base}) + $signed(gain_adjust);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lms_accum      <= 0;
            gain_corrected <= {GAIN_BASE_WIDTH{1'b0}};
        end else begin
            lms_accum <= accum_next;

            // 饱和加法：gain_base + gain_adjust
            if ($signed(gain_sum) >= $signed({1'b0, {GAIN_BASE_WIDTH{1'b1}}}))
                gain_corrected <= {GAIN_BASE_WIDTH{1'b1}};
            else if ($signed(gain_sum) <= 0)
                gain_corrected <= {GAIN_BASE_WIDTH{1'b0}};
            else
                gain_corrected <= gain_sum[GAIN_BASE_WIDTH-1:0];
        end
    end

endmodule
