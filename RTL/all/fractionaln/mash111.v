`timescale  1ns / 1ps

module mash111 #(
    parameter WIDTH = 24,  // 小数分频的位宽
    parameter A_GAIN = 1   // A = A_GAIN*2-1, 控制反馈的大小，具体原理去论文中看
) (
    input clk,             // 时钟输入
    input clk_ila,             // 时钟输入
    input rst_n,           // 复位信号，低有效

    input [WIDTH-1:0] x_i, // Sigma-Delta 调制器的输入，即分频中小数的输入
    output reg [3:0] y_o,      // 量化输出
    output [WIDTH-1:0] e_o, // 最后一级 EFM 的误差输出
    output [WIDTH-1:0] e1_o, // 第1级 EFM 原始误差 (用于 3 阶 DTC 补偿)
    output [WIDTH-1:0] e2_o, // 第2级 EFM 原始误差
    output [WIDTH-1:0] e3_o  // 第3级 EFM 原始误差
);

    wire [WIDTH-1:0] x_i_1;
    wire [WIDTH-1:0] e_o_1;
    wire y_o_1;
    wire [WIDTH-1:0] x_i_2;
    wire [WIDTH-1:0] e_o_2;
    wire y_o_2;
    wire [WIDTH-1:0] x_i_3;
    wire [WIDTH-1:0] e_o_3;
    wire y_o_3;
    
    
    reg y2_d;
    reg y3_d;
    reg y3_dd;

    wire signed [2:0] c1;
    wire signed [3:0] c2;
    reg signed [0:0] c0_reg;
    reg signed [2:0] c1_reg; 

    wire [1:0] stage_sel;
    wire  mash_eo_mode;
    reg [WIDTH-1:0] eo_d1;

        
    // 前一级 efm 的误差输出作为后一级 efm 的输入
    assign x_i_1 = x_i;
    assign x_i_2 = e_o_1;
    assign x_i_3 = e_o_2;

    // 将 3 级 efm 的输出求和
    assign c1 = y_o_2 + y_o_3 - c0_reg;
    assign c2 = y_o_1 + {c1[2], c1} - {c1_reg[2], c1_reg}; // 补全符号位

//    assign y_o = c2;

    // 暴露三级 EFM 原始误差给外部 combiner
    assign e1_o = e_o_1;
    assign e2_o = e_o_2;
    assign e3_o = e_o_3;
    // 为兼容旧接口, 保留 e_o (输出 e1 带 1 拍延迟)
    assign e_o = eo_d1;

    // 延迟
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c0_reg <= 'b0;
            c1_reg <= 'b0;
            y2_d  <= 1'b0;
            y3_d  <= 1'b0;
            y3_dd <= 1'b0;
        end else begin
            c0_reg <= y_o_3;
            c1_reg <= c1;
            y2_d <= y_o_2;
            y3_d <= y_o_3;
            y3_dd <= y3_d;
        end 
    end
    
        always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eo_d1 <= 1'b0;
			y_o <= 4'b0;
        end else begin
            eo_d1 <= e_o_1;
			y_o <=  (stage_sel == 2'b00) ? c2 :
					(stage_sel == 2'b01) ? y_o_1 :
					(stage_sel == 2'b10) ? y_o_1 + y_o_2 - y2_d : y_o_1 + y_o_2 - y2_d + (y_o_3 - y3_d - y3_d + y3_dd);
        end 
		end


    // 三级 efm 级联
    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_1 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_1   ),

        .y_o                     ( y_o_1   ),
        .e_o                     ( e_o_1   )
    );

    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_2 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_2   ),

        .y_o                     ( y_o_2   ),
        .e_o                     ( e_o_2   )
    );

    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_3 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_3   ),

        .y_o                     ( y_o_3   ),
        .e_o                     ( e_o_3   )
    );
//    assign stage_sel = 2'b01;
    mash_stage u_mash_stage (
        .clk (clk),
        .probe_out0 (stage_sel),
        .probe_out1 (mash_eo_mode)
    );
    
        ila_1 u_ila (
        .clk    (clk_ila),
        .probe0 (x_i_1),
        .probe1 (e_o_1),
        .probe2 (e_o_2),
        .probe3 (e_o_3),  // 3-bit 扩展为 4-bit 匹配 ILA 宽度，或按实际 ILA 配置调整
        .probe4 (y_o)  // 3-bit 扩展为 4-bit 匹配 ILA 宽度，或按实际 ILA 配置调整
    );
    
endmodule