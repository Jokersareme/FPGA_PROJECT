`timescale 1ns / 1ps
// 简化 lut_dtc 模型 — 每级固定 50ps 延迟，无 CARRY8 级联
module lut_dtc #(parameter N_TAP=512, parameter CODE_WIDTH=9)(
    input wire sys_clk, input wire rst_n, input wire din,
    input wire [CODE_WIDTH-1:0] code, input wire cal_mode,
    input wire dtc_sel, output wire dout,
    output reg [CODE_WIDTH-1:0] cal_result, output reg cal_valid);
    // 单级固定 50ps 延迟 (替换原来的 512级CARRY8链)
    assign #0.050 dout = din;
    // TDC 占位 (仿真中不实际测量)
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin cal_valid <= 1'b0; cal_result <= 0; end
        else cal_valid <= 1'b0;
    end
endmodule
