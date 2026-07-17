`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/16 17:07:32
// Design Name: 
// Module Name: lut_dtc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
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

    localparam N_CARRY = N_TAP / 8;  // 64

    // CARRY8 的 8-bit CO 输出：co[实例][位]
    (* KEEP = "TRUE" *) wire [7:0] co [0:N_CARRY-1];

    // 展平成 512-bit tap：tap[i*8+j] = co[i][j]
    (* KEEP = "TRUE" *) wire [N_TAP-1:0] tap;

    genvar i, j;
    generate
        for (i = 0; i < N_CARRY; i = i + 1) begin : flatten
            for (j = 0; j < 8; j = j + 1) begin : tap_map
                assign tap[i*8+j] = co[i][j];
            end
        end
    endgenerate

    // 第一级：信号从 CI 输入
    (* DONT_TOUCH = "TRUE" *)
    CARRY8 #(
        .CARRY_TYPE("SINGLE_CY8")
    ) u_carry_0 (
        .CO     (co[0]),
        .O      (),
        .CI     (din),          // 信号输入
        .CI_TOP (1'b0),
        .DI     (8'b0),
        .S      (8'hFF)         // 强制走进位传播路径
    );

    // 后续 63 级：上级 CO[7] → 下级 CI
    generate
        for (i = 1; i < N_CARRY; i = i + 1) begin : cascade
            (* DONT_TOUCH = "TRUE" *)
            CARRY8 #(
                .CARRY_TYPE("SINGLE_CY8")
            ) u_carry (
                .CO     (co[i]),
                .O      (),
                .CI     (co[i-1][7]),   // 接上级第 7 位（最高进位输出）
                .CI_TOP (1'b0),
                .DI     (8'b0),
                .S      (8'hFF)
            );
        end
    endgenerate

    // 输出选择：LUT MUX（Vivado 综合成 3~4 级 LUT 树）
    assign dout = (code < N_TAP) ? tap[code] : tap[N_TAP-1];

//    // 测量逻辑（默认赋值，防止被优化；后续可扩展）
//    always @(posedge sys_clk or negedge rst_n) begin
//        if (!rst_n) begin
//            cal_result <= 0;
//            cal_valid  <= 0;
//        end else begin
//            cal_result <= cal_result;
//            cal_valid  <= cal_valid;
//        end
//    end

endmodule