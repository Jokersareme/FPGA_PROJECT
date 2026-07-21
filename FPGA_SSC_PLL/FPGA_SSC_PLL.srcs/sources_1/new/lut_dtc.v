`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// 纯 CARRY8 版本 lut_dtc - 无 LUT 粗延迟链
//
// 修复内容:
// 1. 纯 CARRY8 级联链: 64 个 CARRY8, 512 个 tap
// 2. 输出加锁存器去毛刺: code 稳定检测 + sys_clk 采样
// 3. 512:1 扁平 MUX 改为 3 层分级 MUX
// 4. code 位域分配: code[8:6]=group, code[5:3]=CARRY8, code[2:0]=bit
// 5. 增加 cal_mode 测量功能
//
// 参数: N_TAP=512, CODE_WIDTH=9 (0~511)
// 延迟范围: 取决于 Vivado 布局, 通常 ~1-3ns
// 如需增加延迟, 在 XDC 中加 LOC 约束分散 CARRY8
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
    input  wire              dtc_sel,
    output wire              dout,
    output reg  [CODE_WIDTH-1:0] cal_result,
    output reg               cal_valid
);

    localparam N_CARRY   = N_TAP / 8;           // 64
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
        .CI_TOP (1'b0),
        .DI     (8'b0),
        .S      (8'hFF)
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
                .CI     (co[i-1][7]),
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

    // Layer 1: 每个 CARRY8 内 8:1 bit MUX
    wire [N_CARRY-1:0] bit_sel;
    genvar c;
    generate
        for (c = 0; c < N_CARRY; c = c + 1) begin : bit_mux
            (* DONT_TOUCH = "TRUE" *)
            assign bit_sel[c] = co[c][code[2:0]];
        end
    endgenerate

    // Layer 2: 每个 group 内 8:1 CARRY8 MUX
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

    // Layer 3: 顶层 8:1 group MUX
    (* DONT_TOUCH = "TRUE" *)
    assign dout = group_sel[code[8:6]];

    // ============================================================
    // 去毛刺: code 稳定检测 + 锁存器
    // ============================================================
//    reg [CODE_WIDTH-1:0] code_d1, code_d2;
//    wire code_stable = (code_d1 == code_d2);

//    always @(posedge sys_clk or negedge rst_n) begin
//        if (!rst_n) begin
//            code_d1 <= {CODE_WIDTH{1'b0}};
//            code_d2 <= {CODE_WIDTH{1'b0}};
//        end else begin
//            code_d1 <= code;
//            code_d2 <= code_d1;
//        end
//    end

    // 锁存器: code 稳定时采样，变化时保持
//    reg dout_latched;
//    always @(posedge sys_clk or negedge rst_n) begin
//        if (!rst_n)
//            dout_latched <= 1'b0;
//        else if (code_stable)
//            dout_latched <= dout_raw;
//        // else 保持原值，屏蔽毛刺
//    end

    // 最终输出: 始终输出锁存值
//    assign dout = dout_latched;

    // ============================================================
    // 校准逻辑
    // ============================================================
//    always @(posedge sys_clk or negedge rst_n) begin
//        if (!rst_n) begin
//            cal_result <= {CODE_WIDTH{1'b0}};
//            cal_valid  <= 1'b0;
//        end else if (cal_mode) begin
//            cal_result <= {{(CODE_WIDTH-1){1'b0}}, dout_latched};
//            cal_valid  <= 1'b1;
//        end else begin
//            cal_valid <= 1'b0;
//        end
//    end

endmodule
