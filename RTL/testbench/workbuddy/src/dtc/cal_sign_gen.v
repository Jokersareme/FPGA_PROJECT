`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: cal_sign_gen
//
// 校准符号位产生模块 — Bang-Bang 相位检测器
//
// 输入 ref 时钟与 fb 时钟（DTC 补偿后的分频输出），
// 输出 1-bit 相位符号 sign，送给 dtc_gain_lms_cal 用于 LMS 相关运算。
//
// 功能：
//   在 ref 的上升沿采样 fb，若 fb 为高则说明 fb 已提前到来
//   → ref 滞后于 fb → DTC 补偿不足（gain 偏低）；
//   若 fb 为低则说明 fb 尚未到来
//   → ref 领先于 fb → DTC 补偿过度（gain 偏高）。
//
// 输出约定：
//   sign = 1 → DTC 补偿不足（gain 偏低需增加）
//   sign = 0 → DTC 补偿过度（gain 偏高需减小）
//
// 参考：
//   [1] "A 6-9GHz DTC-based Fractional-N Sub-sampling PLL" (28nm CMOS)
//   [2] "A 28-nm 75-fsrms Analog Fractional-N Sampling PLL With a Highly
//       Linear DTC Incorporating Background DTC Gain Calibration" (JSSC 2019)
//   [3] EP2782255A1 - "Fractional-N frequency synthesizer using a
//       subsampling PLL and method for calibrating the same"
////////////////////////////////////////////////////////////////////////////////

module cal_sign_gen (
    input  wire  clk_ref,      // 参考时钟（域外）
    input  wire  clk_fb,       // 反馈时钟（经 DTC 补偿后）
    input  wire  rst_n,        // 异步复位，低有效
    output wire  sign          // 相位符号：1 = fb 提前（gain 偏低）
                                //           0 = ref 提前（gain 偏高）
);

    // -----------------------------------------------------------------------
    // DFF: 在 ref 上升沿采样 fb
    //   相对于 ref 上升沿：
    //     - fb 已为高 → fb 领先 → sign = 1
    //     - fb 为低   → ref 领先 → sign = 0
    // -----------------------------------------------------------------------
    reg fb_sample;
    always @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n)
            fb_sample <= 1'b0;
        else
            fb_sample <= clk_fb;
    end

    assign sign = fb_sample;

endmodule
