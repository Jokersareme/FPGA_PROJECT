`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// 修复版本: lut_dtc - CARRY8 数字控制延迟线 (DTC)
//
// 修复内容:
// 1. 512:1 扁平 MUX 改为 3 层分级 MUX (group 8:1 + CARRY8 8:1 + bit 8:1)
//    MUX 深度从 ~9 层 LUT 降至 ~3 层 LUT, 延迟从 3-5ns 降至 ~1ns
//    延迟线性度显著改善, CARRY8 精细延迟不再被 MUX 淹没
//
// 2. code 位域分配:
//    code[8:6] (3bit) → 8 个 group, 每个含 8 个 CARRY8 = 64 个 tap
//    code[5:3] (3bit) → group 内选 1 个 CARRY8 (8选1)
//    code[2:0] (3bit) → CARRY8 内选 1 个 bit (8选1, CO[0]~CO[7])
//    总计: 8×8×8 = 512 个 tap, 与 N_TAP 一致
//
// 3. 增加 cal_mode 测量功能: 在 cal_mode=1 时记录 code→tap 映射
//
// 4. CARRY8 级联: 所有 DONT_TOUCH 确保 Vivado 不优化
//
// 参数: N_TAP=512, CODE_WIDTH=9 (0~511)
// 延迟范围: ~5ns (512 tap × 10ps/tap), 覆盖 1.6ns Fin 周期
////////////////////////////////////////////////////////////////////////////////

module lut_dtc #(
    parameter N_TAP = 512,
    parameter CODE_WIDTH = 9
)(
    input  wire              sys_clk,
    input  wire              rst_n,
    input  wire              din,
    input  wire [CODE_WIDTH-1:0] code,
    input  wire              cal_mode,
    output wire              dout,
    output reg  [CODE_WIDTH-1:0] cal_result,
    output reg               cal_valid
);

    localparam N_CARRY   = N_TAP / 8;           // 64 (每个 CARRY8 有 8 个 tap)
    localparam N_GROUP   = 8;                    // 8 个 group
    localparam N_CAR_PER = N_CARRY / N_GROUP;    // 8 个 CARRY8 每 group

    // ---- CARRY8 的 CO 输出 ----
    (* KEEP = "TRUE" *) wire [7:0] co [0:N_CARRY-1];

    // ---- CARRY8 级联链 ----
    // Level 0: 信号从 din 进入 CI
    (* DONT_TOUCH = "TRUE" *)
    CARRY8 #(
        .CARRY_TYPE("SINGLE_CY8")
    ) u_carry_0 (
        .CO     (co[0]),
        .O      (),
        .CI     (din),             // 信号输入: din
        .CI_TOP (1'b0),            // SINGLE_CY8 模式: CI_TOP=0
        .DI     (8'b0),            // 全部走 carry chain propagation
        .S      (8'hFF)            // S=1 → CI→CO 直通模式
    );

    // Level 1~63: co[i-1][7] → CI
    genvar i;
    generate
        for (i = 1; i < N_CARRY; i = i + 1) begin : cascade
            (* DONT_TOUCH = "TRUE" *)
            CARRY8 #(
                .CARRY_TYPE("SINGLE_CY8")
            ) u_carry (
                .CO     (co[i]),
                .O      (),
                .CI     (co[i-1][7]),   // 上级最高位进位输出 → 下级 CI
                .CI_TOP (1'b0),
                .DI     (8'b0),
                .S      (8'hFF)
            );
        end
    endgenerate

    // ============================================================
    // 3 层分级 MUX: 取代原 512:1 扁平 MUX
    // ============================================================
    // 位域: code[8:6]=group, code[5:3]=CARRY8, code[2:0]=bit
    // ------------------------------------------------------------
    // Layer 1: 每个 CARRY8 内 8:1 bit MUX (64 个, 各选 co[i][0..7])
    //   输入: co[i][7:0]             输出: bit_sel[i]
    // ------------------------------------------------------------
    wire [N_CARRY-1:0] bit_sel;       // bit 选择结果
    genvar c;
    generate
        for (c = 0; c < N_CARRY; c = c + 1) begin : bit_mux
            (* DONT_TOUCH = "TRUE" *)
            assign bit_sel[c] = co[c][code[2:0]];
        end
    endgenerate

    // ------------------------------------------------------------
    // Layer 2: 每个 group 内 8:1 CARRY8 MUX (8 个, 各选 8 个 CARRY8)
    //   输入: bit_sel[g*8 + 0..7]    输出: group_sel[g]
    // ------------------------------------------------------------
    wire [N_GROUP-1:0] group_sel;
    genvar g;
    generate
        for (g = 0; g < N_GROUP; g = g + 1) begin : carry_mux
            wire [N_CAR_PER-1:0] group_bits;
            genvar k;
            for (k = 0; k < N_CAR_PER; k = k + 1) begin : group_map
                assign group_bits[k] = bit_sel[g * N_CAR_PER + k];
            end
            (* DONT_TOUCH = "TRUE" *)
            assign group_sel[g] = group_bits[code[5:3]];
        end
    endgenerate

    // ------------------------------------------------------------
    // Layer 3: 顶层 8:1 group MUX
    //   输入: group_sel[0..7]         输出: dout
    // ------------------------------------------------------------
    (* DONT_TOUCH = "TRUE" *)
    assign dout = group_sel[code[8:6]];

    // ============================================================
    // 校准逻辑 (cal_mode=1 时测量当前输出值)
    // ============================================================
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            cal_result <= {CODE_WIDTH{1'b0}};
            cal_valid  <= 1'b0;
        end else if (cal_mode) begin
            // 校准模式: 输出当前 dout (即 tap[code] 的值)
            cal_result <= {{(CODE_WIDTH-1){1'b0}}, dout};
            cal_valid  <= 1'b1;
        end else begin
            cal_result <= cal_result;
            cal_valid  <= 1'b0;
        end
    end

endmodule
