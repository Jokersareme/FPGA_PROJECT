`timescale  1ns / 1ps

// P/S 双模分频器
module dual_div #(
    parameter P_WIDTH = 6,
    parameter S_WIDTH = 2
) (
    input wire clk,              // 时钟输入
    input wire clk_ila,              // 时钟输入
    input wire rst_n,            // 复位信号，低有效
    input wire [S_WIDTH-1:0] Si, // S 计数器的最大值
    input wire [P_WIDTH-1:0] Pi, // P 计数器的最大值

    output wire Fdiv             // 分频输出
);
// 8/9分频改为4/5分频
    wire  f45;
    wire  MC;
    wire  LD;
	reg MC_dly;
	reg [3:0] ss_cnt;

    ila_dualdiv u_ila_dualdiv (
        .clk(clk_ila), // input wire clk
    
    
        .probe0(Pi), // input wire [5:0]  probe0  
        .probe1(Si), // input wire [1:0]  probe1 
        .probe2({f45,Fdiv}), // input wire [1:0]  probe2 
        .probe3({MC,MC_dly}), // input wire [1:0]  probe3 
        .probe4(ss_cnt), // input wire [3:0]  probe4 
        .probe5(LD) // input wire [0:0]  probe5
    );


    div_45  u_div_45 (
        .clk                     ( clk 			   ),
        .rst_n                   ( rst_n  		   ),
        .MC                      ( MC_dly    		   ),

        .f45                     ( f45   		   )
    );

    p_counter #(
        .WIDTH ( P_WIDTH ))
    u_p_counter (
        .rst_n                   ( rst_n   ),
        .Fin                     ( f45     ),
        .Pi                      ( Pi      ),

        .Fout                    ( Fdiv    ),
        .LDo                     ( LD      )
    );

    s_counter #(
        .WIDTH ( S_WIDTH ))
    u_s_counter (
        .Fin                     ( f45   ),
        .Si                      ( Si    ),
        .LDi                     ( LD    ),

        .MCo                     ( MC    )
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MC_dly <= 1'b0;
			ss_cnt <= 4'd0;
		end else if (ss_cnt==4'd15) begin
			MC_dly <= MC;
			ss_cnt <= ss_cnt;
        end else begin
			ss_cnt <= ss_cnt + 1'd1;
			MC_dly <= MC_dly;
        end
    end

endmodule