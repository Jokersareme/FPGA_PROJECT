`timescale  1ns / 1ps

module mash111 #(
<<<<<<< HEAD:RTL/all/fractionaln/mash111.v
    parameter WIDTH = 24,  // 小数分频的位�?
    parameter A_GAIN = 1   // A = A_GAIN*2-1, 控制反馈的大小，具体原理去论文中�?
=======
    parameter WIDTH = 24,  // ???????
    parameter A_GAIN = 1   // A = A_GAIN*2-1, ?????????????????
>>>>>>> 8629b95e8b5cabbef3b86820dfc873125dc45141:RTL/testbench/workbuddy/src/fractionaln/mash111.v
) (
    input clk,             // ????
    input clk_ila,             // ????
    input rst_n,           // ????????

<<<<<<< HEAD:RTL/all/fractionaln/mash111.v
    input [WIDTH-1:0] x_i, // Sigma-Delta 调制器的输入，即分频中小数的输入
    output reg [3:0] y_o,      // 量化输出
    output [WIDTH-1:0] e_o, // 最后一�?EFM 的误差输�?
    output [WIDTH-1:0] e3_o  // ��3�� EFM ԭʼ��� (���� DTC ����)
=======
    input [WIDTH-1:0] x_i, // Sigma-Delta ????????????????
    output reg signed [3:0] y_o,      // ????
    output reg  y2_o,      // ????
    output [WIDTH-1:0] e_o
>>>>>>> 8629b95e8b5cabbef3b86820dfc873125dc45141:RTL/testbench/workbuddy/src/fractionaln/mash111.v
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
    
    
    reg y2_d = 0;
    reg y3_d = 0;
    reg y3_dd = 0;

    wire signed [2:0] c1;
    wire signed [3:0] c2;
    reg signed [0:0] c0_reg = 0;
    reg signed [2:0] c1_reg = 0; 

    wire [1:0] stage_sel;
    wire  mash_eo_mode;
    reg [WIDTH-1:0] eo_d1 = 0;

        
<<<<<<< HEAD:RTL/all/fractionaln/mash111.v
    // 前一�?efm 的误差输出作为后一�?efm 的输�?
=======
    // ??? efm ?????????? efm ???
>>>>>>> 8629b95e8b5cabbef3b86820dfc873125dc45141:RTL/testbench/workbuddy/src/fractionaln/mash111.v
    assign x_i_1 = x_i;
    assign x_i_2 = e_o_1;
    assign x_i_3 = e_o_2;

<<<<<<< HEAD:RTL/all/fractionaln/mash111.v
    // �?3 �?efm 的输出求�?
    assign c1 = y_o_2 + y_o_3 - c0_reg;
    assign c2 = y_o_1 + {c1[2], c1} - {c1_reg[2], c1_reg}; // 补全符号�?

//    assign y_o = c2;

    // 暴露三级 EFM 原始误差给外�?combiner
            assign e3_o = e_o_3;
    // 为兼容旧接口, 保留 e_o (输出 e1 �?1 拍延�?
=======
    // ? 3 ? efm ?????
    assign c1 = y_o_2 + y_o_3 - c0_reg;
    assign c2 = y_o_1 + {c1[2], c1} - {c1_reg[2], c1_reg}; // ?????

//    assign y_o = c2;

    // ???? EFM ??????? combiner
    assign e1_o = e_o_1;
    assign e2_o = e_o_2;
    assign e3_o = e_o_3;
    // ??????, ?? e_o (?? e1 ? 1 ???)
>>>>>>> 8629b95e8b5cabbef3b86820dfc873125dc45141:RTL/testbench/workbuddy/src/fractionaln/mash111.v
    assign e_o = eo_d1;

    // ??
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
			y2_o <= 4'b0;
        end else begin
            eo_d1 <= e_o_1;
			y2_o <= y_o_2;
			y_o <=  (stage_sel == 2'b00) ? c2 :
					(stage_sel == 2'b01) ? y_o_1 :
					(stage_sel == 2'b10) ? $signed(y_o_1) + $signed(y_o_2) - $signed(y2_d) : $signed(y_o_1) + $signed(y_o_2) - $signed(y2_d);
        end 
		end


    // ?? efm ??
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
<<<<<<< HEAD:RTL/all/fractionaln/mash111.v
        .probe3 (e_o_3),  // 3-bit 扩展�?4-bit 匹配 ILA 宽度，或按实�?ILA 配置调整
        .probe4 (y_o)  // 3-bit 扩展�?4-bit 匹配 ILA 宽度，或按实�?ILA 配置调整
=======
        .probe3 (e_o_3),  // 3-bit ??? 4-bit ?? ILA ??????? ILA ????
        .probe4 (y_o)  // 3-bit ??? 4-bit ?? ILA ??????? ILA ????
>>>>>>> 8629b95e8b5cabbef3b86820dfc873125dc45141:RTL/testbench/workbuddy/src/fractionaln/mash111.v
    );
    
endmodule
