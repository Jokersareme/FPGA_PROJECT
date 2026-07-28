`timescale 1ns / 1ps

// 输入位宽: WIDTH 可配; SHIFT 控制乘法结果右移量
// 限制: dtc_comp 的 SHIFT 必须与 dtc_calibrator 的 SHIFT 一致 (否则多 2^diff 因子)
// 目前两处都用 SHIFT=11 (SHIFT=12 时 K_BASE=32704, 10-bit gain 装不下)
// order_sel 仅控制 offset 自动居中: 1阶=0, 3阶=256
module dtc_comp #(
    parameter WIDTH = 12,
    parameter SHIFT = 10,       // 必须与 dtc_calibrator.SHIFT 一致
    parameter DTC_WIDTH = 9
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire [WIDTH-1:0]  e1,
    input  wire [9:0]        dtc_gain,
    input  wire              dtc_en,
    input  wire [DTC_WIDTH-1:0] dtc_offset,   // VIO 微调 offset (0~511)
    input  wire              order_sel,        // 0=1阶, 1=3阶(加256居中)
    output wire  [DTC_WIDTH-1:0] dtc_code,
    output wire               dtc_load         // 仅用于 ILA 观测, 无实际功能
);

    wire dtc_code_man_en;
    wire [9:0] dtc_code_man;

    // 3阶自动居中 offset (+256), 1阶不加
    // VIO 的 dtc_offset 作为微调
    wire [DTC_WIDTH-1:0] center_offset = order_sel ? (1 << (DTC_WIDTH-1)) : {DTC_WIDTH{1'b0}};

    // 乘法: e1 有符号, dtc_gain 无符号
    // 位宽: WIDTH+10 = 23-bit signed
    wire signed [WIDTH+9:0] mult = $signed({{10{e1[WIDTH-1]}}, e1}) * $signed({1'b0, dtc_gain});

    // 从 mult 中提取有效位
    // 问题: mult[SHIFT +: 10] (只取 10-bit) 在 3 阶误差较大时会溢出
    //   例如 e=4095, gain=1023: mult=4,189,185, mult[20:11]=2045 > 511
    //   10-bit signed 只能表示 -512~511, 2045 会截断为 -3 → code 算错
    // 修复: 提取 12-bit (DTC_WIDTH+3), 足以覆盖最大值 2045
    //   mult[22:11] = mult >> 11, 12-bit signed, 范围 -2048~2047, 安全
    wire signed [DTC_WIDTH+2:0] mult_ext = $signed(mult[SHIFT +: DTC_WIDTH+3]);

    // code_signed 用 13-bit (DTC_WIDTH+4) 防加法溢出
    //   max mult_ext=2045, + center_offset=256, + dtc_offset=511 → 2812 < 4095 ✓
    wire signed [DTC_WIDTH+3:0] code_signed = $signed(mult_ext)
                                            + $signed({{4{1'b0}}, center_offset})
                                            + $signed({{4{1'b0}}, dtc_offset});

    // 饱和到 0~511, 使用 10'sd511 避免 9'sd511=-1 的 bug
    wire [DTC_WIDTH-1:0] code_sat = (code_signed > 10'sd511) ? {DTC_WIDTH{1'b1}} :
                                     (code_signed < 0)       ? {DTC_WIDTH{1'b0}} :
                                     code_signed[DTC_WIDTH-1:0];
    
    
    // dtc_code 组合输出, 经 dtc_code_pipe/Fout 域寄存器后再进 CARRY8
    assign dtc_code = dtc_en ? (dtc_code_man_en ? dtc_code_man[DTC_WIDTH-1:0] : code_sat) : {DTC_WIDTH{1'b0}};

    // dtc_load: 仅用于 ILA 观测 (IDELAYE3 已取消), 始终为 1
    assign dtc_load = dtc_en;

    vio_1 u_vio_dtc_comp (
  .clk(clk),                // input wire clk
  .probe_out0(dtc_code_man_en),  // output wire [0 : 0] probe_out0
  .probe_out1(dtc_code_man)  // output wire [8 : 0] probe_out1
);


endmodule
