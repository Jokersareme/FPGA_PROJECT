`timescale  1ns / 1ps

// 整个小数分频器的顶层模块，包�?mash111-Sigma-Delta 调制器，双模分频�?
module fractionaln #(
    parameter P_WIDTH = 6,                  // P 计数器的位宽
    parameter S_WIDTH = 2,                  // S 计数器的位宽
    parameter INT_WIDTH = 8,                // 分频整数的位�?
    parameter FRAC_WIDTH = 10               // 分频小数的位�?
) (
    input wire Fin,                         // 分频器的时钟输入
    input wire Sys_clk,                         // 分频器的时钟输入
    input wire rst_n,                       // 复位信号，低有效
    input wire order_sel,                       // 复位信号，低有效

    input wire [INT_WIDTH-1:0] Integer,     // 分频整数部分
    input wire [FRAC_WIDTH-1:0] Fraction,   // 分频小数部分
    
    output reg [FRAC_WIDTH-1:0] Eo,          // 1 阶误�?(原接�?
    output reg signed [FRAC_WIDTH:0] E_combined,  // 3 阶组合误�?(用于 3 �?DTC 补偿)
    output wire Fout                         // 分频输出
);

	wire rst_n_sync;
    wire [3:0] delta_sigma;
    wire clk_delta_sigma;
    wire [S_WIDTH-1:0] Si;
    wire [P_WIDTH-1:0] Pi;
    //reg Fout_reg;
    wire [FRAC_WIDTH-1:0] Eo_raw;
    reg [FRAC_WIDTH-1:0] Eo_d1;

	reg signed [FRAC_WIDTH:0] sigma = 0;
	wire signed [FRAC_WIDTH:0] sigma_w;


    assign clk_delta_sigma = Fout;
	reg [3:0] delta_sigma_d1 = 0;
	wire c2_o;
	
	wire [1:0] eo_dly_sel;

	assign sigma_w = $signed({1'b0, Eo_raw}) - c2_o * $signed(12'sd1024);



    always @(negedge Fout or negedge rst_n) begin
        if (!rst_n) begin
            delta_sigma_d1 <= 0;
            E_combined <= 'd0;
			sigma <= 'd0;
            Eo <= 'd0;
            Eo_d1 <= 'd0;
        end else begin
            Eo_d1 <= Eo_raw;
            Eo <= Eo_d1;
            delta_sigma_d1 <= delta_sigma;
			sigma <= sigma_w;
            E_combined <= sigma;
        end 
    end
           
    
    //assign Fout = Fout_reg;
    
	dff  u_sync_rstn_dff (
        .clk                     ( Fin      ),
        .LD                      ( 1'b0     ),
		.rst_n					 ( 1'b1		),
        .P                       ( 1'b1     ),
        .D                       ( rst_n    ),

        .Q                       ( rst_n_sync     ),
        .Qn                      (     )
    );

    // Sigma-Delta 调制�?(现在输出三级 EFM 原始误差)
    mash111 #(
        .WIDTH  ( FRAC_WIDTH ),
        .A_GAIN ( 1  ))
    u_mash111 (
        .clk                     ( clk_delta_sigma ),
        .clk_ila                 ( Sys_clk         ),
        .rst_n                   ( rst_n_sync      ),
        .order_sel                   ( order_sel      ),
        .x_i                     ( Fraction        ),

        .y_o                     ( delta_sigma     ),
        .c2_o                     ( c2_o     ),
        .e_o                     ( Eo_raw          )
    );

    // 将分频的整数部分�?Sigma-Delta 调制器的结果相加，将结果分成两部分分别送到 P 计数器和 S 计数�?
    calculate_ps #(
        .P_WIDTH   ( P_WIDTH ),
        .S_WIDTH   ( S_WIDTH ),
        .INT_WIDTH ( INT_WIDTH ))
    u_calculate_ps (
        .clk                     ( ~clk_delta_sigma ),
        .rst_n                   ( rst_n_sync      ),
        .Integer                 ( Integer         ),
        .delta_sigma             ( delta_sigma_d1     ),
		.Ei						 ( Eo_raw		   ),
        .Si                      ( Si              ),
        .Pi                      ( Pi              ),
		.Eo						 (    		   )
    );
    
    // P/S 双模分频�?
    dual_div #(
        .P_WIDTH ( P_WIDTH ),
        .S_WIDTH ( S_WIDTH ))
    u_dual_div (
        .clk                     ( Fin        ),
        .clk_ila                 ( Sys_clk    ),
        .rst_n                   ( rst_n_sync ),
        .Si                      ( Si         ),
        .Pi                      ( Pi         ),

        .Fdiv                    ( Fout       )
    );    
    
endmodule


