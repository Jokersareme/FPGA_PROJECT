`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: phase_align_cal
//
// 相位对齐校准模块 — 校准 cal_sign_gen 内两时钟的静态相位偏差
//
// 由于 ref 与 fb 之间存在未知的固定相位偏移（由路径延迟、缓冲器延迟等
// 引入），若直接送入 BBPD 会导致 sign 输出偏置（持续为 0 或 1），
// 使 dtc_gain_lms_cal 无法正常工作。本模块通过在 ref 路径上插入
// 可编程延迟（IDELAYE3），将两时钟边缘的静态相位差归零。
//
// 工作原理：
//   - 统计 sign_in 中 1 的比例 → 反映两时钟的静态相位差
//   - 使用一阶积分器（accumulator）跟踪平均相位偏置
//   - 积分器高位输出 delay_code → IDELAYE3 的 CNTVALUEIN
//   - 环路收敛后 sign_in 应在 50% duty 附近随机摆动
//
// 延迟分辨率由 IDELAYE3 原生 40ps/tap 决定（共 32 taps），
// 覆盖范围 32 × 40ps = 1.28ns。
//
// 参考：
//   [1] EP2782255A1 - 阈值失配/相位偏置校准概念
//   [2] "A 6-9GHz DTC-based Fractional-N Sub-sampling PLL" -
//       阈值失调校准（threshold mismatch calibration）
////////////////////////////////////////////////////////////////////////////////

module phase_align_cal #(
    parameter ACCUM_WIDTH = 24,       // 积分器位宽
    parameter DELAY_WIDTH = 9         // IDELAYE3 延迟码位宽（9 原为 9 位，
                                      // 但 5-bit 足以覆盖 32 taps）
) (
    input  wire                clk,          // 系统时钟（sys_clk_g，用于状态更新）
    input  wire                rst_n,        // 异步复位
    input  wire                sign_in,      // 来自 cal_sign_gen 的相位符号
    output reg  [DELAY_WIDTH-1:0] delay_code // 延迟控制码 → IDELAYE3.CNTVALUEIN
);

    // -----------------------------------------------------------------------
    // 数字积分器 (digital integrator / accumulator)
    // 原理：每拍根据 sign_in 做 ±1 累加。高位为 delay_code。
    //   sign_in = 1 → DTC 补偿不足 → fb 偏早 → 加 ref 延迟 → 积分器 +
    //   sign_in = 0 → DTC 补偿过度 → fb 偏晚 → 减 ref 延迟 → 积分器 -
    //
    // 积分器高位直接截取作 delay_code，形成负反馈：
    //   积分器 ↑ → delay ↑ → ref 更晚 → sign_in ↓ → 积分器 ↓
    //   积分器 ↓ → delay ↓ → ref 更早 → sign_in ↑ → 积分器 ↑
    // -----------------------------------------------------------------------
    reg signed [ACCUM_WIDTH-1:0] integ;
    wire signed [ACCUM_WIDTH-1:0] integ_next;

    // 每次根据 sign_in 方向步进 ±1
    // 等效于将 sign_in 看作 1-bit 量化误差，积分器对其做平均
    assign integ_next = integ + (sign_in == 1'b0 ? $signed({{(ACCUM_WIDTH-1){1'b0}}, 1'b1})
                                        : $signed({{(ACCUM_WIDTH-1){1'b1}}, 1'b1}));
                                        // +1 when sign=1, -1 when sign=0

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integ      <= 0;
            delay_code <= {DELAY_WIDTH{1'b0}};
        end else begin
            integ      <= integ_next;
            // 取积分器高 DELAY_WIDTH 位作延迟码（带符号截取）
            // 截取后映射到 [0, 2^DELAY_WIDTH-1] 范围
            // 中间值 = 2^(DELAY_WIDTH-1) 对应零相位偏移
            delay_code <= integ_next[ACCUM_WIDTH-1 -: DELAY_WIDTH]
                        + (1 << (DELAY_WIDTH-1));
        end
    end

endmodule
