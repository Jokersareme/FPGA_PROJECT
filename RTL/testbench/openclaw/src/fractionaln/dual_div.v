`timescale  1ns / 1ps

// P/S 双模分频器
// 修复: 删除 ss_cnt/MC_dly 延迟链，MC 直接连接
// 原 MC_dly 用自由计数器延迟 MC 信号，导致 4/5 预分频器模数切换错位 → 输出周期突变(毛刺)
// MC 来自 s_counter 的 mc_q，已在 Fin 上寄存并通过 LDi 与分频周期边界同步，无需额外延迟
module dual_div #(
    parameter P_WIDTH = 6,
    parameter S_WIDTH = 2
) (
    input wire clk,              // 时钟输入 (Fin, 625MHz)
    input wire clk_ila,          // ILA 时钟
    input wire rst_n,            // 复位信号，低有效
    input wire [S_WIDTH-1:0] Si, // S 计数器的最大值
    input wire [P_WIDTH-1:0] Pi, // P 计数器的最大值

    output wire Fdiv             // 分频输出
);

    wire  f45;
    wire  MC;
    wire  LD;

    ila_dualdiv u_ila_dualdiv (
        .clk(clk_ila),

        .probe0(Pi),            // input wire [5:0]  probe0
        .probe1(Si),            // input wire [1:0]  probe1
        .probe2({f45,Fdiv}),    // input wire [1:0]  probe2
        .probe3({MC,MC}),       // input wire [1:0]  probe3  (原为{MC,MC_dly}，现两者均为MC)
        .probe4(4'd0),          // input wire [3:0]  probe4  (原为ss_cnt，已删除)
        .probe5(LD)             // input wire [0:0]  probe5
    );

    div_45  u_div_45 (
        .clk                     ( clk        ),
        .rst_n                   ( rst_n      ),
        .MC                      ( MC         ),  // 修复: 原为 MC_dly，现直接用 MC

        .f45                     ( f45        )
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
		.rst_n                   ( rst_n ),
        .Fin                     ( f45   ),
        .Si                      ( Si    ),
        .LDi                     ( LD    ),

        .MCo                     ( MC    )
    );

endmodule
