`timescale 1ns / 1ps
// 覆盖调整版：延长 cal_start 超时（40us→400us），保持 order_sel=1
module vio_cal (
    input               clk,
    output              probe_out0,     // cal_start
    output              probe_out1,     // cal_auto_en
    output              probe_out2,     // order_sel
    input      [9:0]    probe_in0,     // dtc_gain_cal
    input      [0:0]    probe_in1      // cal_done
);
    reg [19:0] cnt = 0;
    reg cal_start_r = 0;
    reg cal_start_done = 0;

    assign probe_out0 = cal_start_r;
    assign probe_out1 = 1'b0;           // cal_auto_en=0 (手动模式)
    assign probe_out2 = 1'b1;           // order_sel=1 (3阶)

    always @(posedge clk) begin
        if (cal_start_done) begin
            // 保持 cal_start=0
            cal_start_r <= 1'b0;
        end else if (cnt < 20'd125) begin         // ~1us @ 125MHz
            cnt <= cnt + 1;
            cal_start_r <= 1'b0;
        end else if (cnt == 20'd125) begin
            cal_start_r <= 1'b1;                   // 0→1 触发校准
            cnt <= cnt + 1;
        end else if (probe_in1) begin              // cal_done 后拉低
            cal_start_r <= 1'b0;
            cal_start_done <= 1'b1;
        end else if (cnt > 20'd50000) begin        // 超时 ~400us
            cal_start_r <= 1'b0;
            cal_start_done <= 1'b1;
        end else begin
            cnt <= cnt + 1;
        end
    end
endmodule
