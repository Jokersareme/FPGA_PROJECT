`timescale  1ns / 1ps

// 修复: 门控时钟 clk_i[0] = ~((~h_and)&(~Fin)) 改为时钟使能方式
// 问题: 组合逻辑生成的门控时钟在 h_and/Fin 变化时会产生毛刺，导致 DFF 误触发
// 修复: clk_i[0] 直接使用 Fin，在 D 输入端加使能逻辑
//       使能 = ~h_and，即计数器未全1时允许翻转，全1时保持
module s_counter #(
    parameter WIDTH = 3
) (
    input rst_n,
    input wire Fin,
    input wire [WIDTH-1:0] Si,
    input wire LDi,

    output wire MCo
);

    wire [WIDTH-1:0] clk_i;
    wire [WIDTH-1:0] d_i;
    wire [WIDTH-1:0] q_o;
    wire [WIDTH-1:0] qn_o;
    wire [WIDTH-1:0] LD_i;

    wire h_and;
    wire mc_d;
    wire mc_q;
    reg rst_n_d1;
    wire ldi;

    genvar i;
    generate
        for(i=0; i<WIDTH; i=i+1) begin:BLOCK1
            dff  u_dff (
                .clk                     ( clk_i[i]   ),
                .LD                      ( LD_i[i]    ),
				.rst_n					 ( rst_n	  ),
                .P                       ( Si[i]      ),
                .D                       ( d_i[i]     ),

                .Q                       ( q_o[i]     ),
                .Qn                      ( qn_o[i]    )
            );
        end
    endgenerate

    dff  u_mc_dff (
        .clk                     ( Fin      ),
        .LD                      ( ~rst_n     ),
		.rst_n			 		 ( rst_n	  ),
        .P                       ( 1'b1     ),
        .D                       ( mc_d     ),

        .Q                       ( mc_q     ),
        .Qn                      (     )
    );

    always @(posedge Fin) begin
        rst_n_d1 <= rst_n;
    end

    assign ldi = (rst_n == 1 & rst_n_d1 == 0) ? 1 : 0;

    // ============================================================
    // 修复: 门控时钟改时钟使能
    // 原: assign clk_i[0] = ~((~h_and)&(~Fin));  -- 门控时钟，有毛刺风险
    // 改为: clk_i[0]=Fin (纯时钟), d_i[0] 在 h_and=1 时保持原值
    // ============================================================
    assign h_and = &qn_o;

    // 修复: bit0 使用 Fin 作为时钟，通过 d_i 实现使能
    assign clk_i[0] = Fin;                           // 纯时钟，无门控
    assign d_i[0]   = h_and ? q_o[0] : qn_o[0];     // 使能逻辑: h_and=1时保持
    assign d_i[WIDTH-1:1] = qn_o[WIDTH-1:1];        // 高位不变

    assign clk_i[WIDTH-1:1] = q_o[WIDTH-2:0];
    assign mc_d = ~(LDi|h_and);
    assign MCo = mc_q;
    assign LD_i = {WIDTH{LDi}};

endmodule
