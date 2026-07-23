`timescale 1ns / 1ps
// 覆盖 xilinx_sim.v 中的 vio_cal，order_sel=0（1阶校准）
// iverilog 后编译此文件即可覆盖同名模块
module vio_cal (
    input               clk,
    output              probe_out0,     // cal_start
    output              probe_out1,     // cal_auto_en
    output              probe_out2,     // order_sel
    input      [9:0]    probe_in0,      // dtc_gain_cal
    input      [0:0]    probe_in1       // cal_done
);
    reg [15:0] cnt = 0;
    reg cal_start_r = 0;

    // cal_auto_en=0 (手动模式)
    // order_sel=0 (1阶补偿)
    assign probe_out0 = cal_start_r;
    assign probe_out1 = 1'b0;
    assign probe_out2 = 1'b0;

    // 系统复位后约 1us 触发校准上升沿
    // cal_start 保持高电平直到 cal_done 或超时
    always @(posedge clk) begin
        if (cnt < 16'd125) begin             // ~1us @ 125MHz
            cnt <= cnt + 1;
        end else if (cnt == 16'd125) begin
            cal_start_r <= 1'b1;
            cnt <= cnt + 1;
        end else if (probe_in1) begin         // cal_done 后拉低
            cal_start_r <= 1'b0;
        end else if (cnt > 16'd5000) begin    // 超时保护 (~40us)
            cal_start_r <= 1'b0;
        end else begin
            cnt <= cnt + 1;
        end
    end
endmodule
