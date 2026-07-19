`timescale 1ns / 1ps

// 理想 DTC：基于 Eo 控制的可变延迟线
// 只在仿真/testbench 中使用，无 FPGA 物理约束
module dtc_ideal #(
    parameter E_WIDTH = 10,
    parameter DELAY_STEP = 0.00977,    // 每 LSB 延迟量，单位 ns
    parameter MAX_DELAY = 10      // 最大延迟 = 256 * 0.01 = 2.56 ns
)(
    input  wire              in,           // 输入信号
    input  wire [E_WIDTH-1:0] Eo,          // MASH 误差控制码（0~255）
    output wire              out           // 延迟后输出
);

    // 理想延迟计算
    real delay_ns;
    
    always @(*) begin
        delay_ns = Eo * DELAY_STEP;  // 线性映射：0~255 → 0~2.56ns
    end
    
    // Verilog 理想延迟语句
    assign #delay_ns out = in;

endmodule
