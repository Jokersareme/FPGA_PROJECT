`timescale  1ns / 1ps

module mash111 #(
    parameter WIDTH = 24,  // 小数分频的位�?
    parameter A_GAIN = 1   // A = A_GAIN*2-1, 控制反馈的大小，具体原理去论文中�?
) (
    input clk,             // 时钟输入
    input clk_ila,             // 时钟输入
    input rst_n,           // 复位信号，低有效
    input order_sel,           // 复位信号，低有效

    input [WIDTH-1:0] x_i, // Sigma-Delta 调制器的输入，即分频中小数的输入
    output reg signed [3:0] y_o,      // 量化输出
    output reg c2_o,      // 量化输出
    output reg [WIDTH-1:0] e_o
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


        
    // 前一�?efm 的误差输出作为后一�?efm 的输�?
    assign x_i_1 = x_i;
    assign x_i_2 = e_o_1;
    assign x_i_3 = e_o_2;




    // 延迟
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y2_d  <= 1'b0;
            y3_d  <= 1'b0;
            y3_dd <= 1'b0;
        end else begin
            y2_d <= y_o_2;
            y3_d <= y_o_3;
            y3_dd <= y3_d;
        end 
    end
    
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                y_o <= 4'b0;
            end else begin
                e_o <= e_o_1;
                c2_o <= y_o_2;
                y_o <=  (order_sel == 1'b0) ? $signed({3'd0,y_o_1}) : $signed({3'd0,y_o_1}) + $signed({3'd0,y_o_2}) - $signed({3'd0,y2_d});
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

    
        ila_1 u_ila (
        .clk    (clk_ila),
        .probe0 (x_i_1),
        .probe1 (e_o_1),
        .probe2 (e_o_2),
        .probe3 ({6'd0,y2_d,y_o_2,y_o_1,c2_o}),  // 3-bit 扩展�?4-bit 匹配 ILA 宽度，或按实�?ILA 配置调整
        .probe4 (y_o)  // 3-bit 扩展�?4-bit 匹配 ILA 宽度，或按实�?ILA 配置调整
    );
    
endmodule
