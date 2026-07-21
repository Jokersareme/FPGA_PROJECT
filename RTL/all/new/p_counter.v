`timescale  1ns / 1ps

// 修复: Fout 由组合逻辑改为寄存器输出，消除 Pi 变化时的组合毛刺
// 原设计: assign Fout = (qn_o == ~Pi_correct | qn_o == ~(Pi_correct-1)) ? 1 : 0;
// 问题: Pi 来自 calculate_ps (~Fout_reg 下降沿更新)，更新时 p_counter 可能正在计数
//       新的 Pi_correct 可能与当前 qn_o 瞬间匹配，在 Fout 上产生窄脉冲
//       Fout_raw → Fout_reg(posedge Fin=625MHz) 会捕获该毛刺
// 修复: Fout 在 Fin(=f45) 上寄存一拍，增加 1 个 f45 周期延迟，对反馈环路影响可忽略
module p_counter #(
    parameter WIDTH = 5
) (
    input wire rst_n,
    input wire Fin,
    input wire [WIDTH-1:0] Pi,

    output reg  Fout,            // 修复: 改为寄存器输出
    output wire LDo
);

    wire [WIDTH-1:0] clk_i;
    wire [WIDTH-1:0] d_i;
    wire [WIDTH-1:0] q_o;
    wire [WIDTH-1:0] qn_o;
    wire [WIDTH-1:0] LD_i;

    wire h_nand;
    wire ld_d;
    wire ld_q;
    wire [WIDTH-1:0] Pi_correct;
    reg rst_n_d1;
    wire ldi;

    // Generate block
    genvar i;
    generate
        for(i=0; i<WIDTH; i=i+1) begin:BLOCK1
            dff  u_dff (
                .clk                     ( clk_i[i]   ),
                .LD                      ( LD_i[i]    ),
                .P                       ( Pi_correct[i]      ),
                .D                       ( d_i[i]     ),

                .Q                       ( q_o[i]     ),
                .Qn                      ( qn_o[i]    )
            );
        end
    endgenerate

    dff  u_ld_dff (
        .clk                     ( Fin      ),
        .LD                      ( ldi   ),
        .P                       ( 1'b1     ),
        .D                       ( ld_d     ),

        .Q                       ( ld_q     ),
        .Qn                      (          )
    );

    always @(posedge Fin) begin
        rst_n_d1 <= rst_n;
    end

    assign ldi = (rst_n == 1 & rst_n_d1 == 0) ? 1 : 0;

    assign Pi_correct = Pi - 1'd1;
    assign d_i = qn_o;
    assign clk_i[0] = Fin;
    assign clk_i[WIDTH-1:1] = q_o[WIDTH-2:0];
    assign h_nand = ~(&qn_o[WIDTH-1:1]);
    assign ld_d = ~(qn_o[0]|h_nand);
    assign LD_i = {WIDTH{ld_q}};
    assign LDo = ld_q;

    // ============================================================
    // 修复: Fout 寄存一拍，消除 Pi 变化时的组合毛刺
    // ============================================================
    always @(posedge Fin or negedge rst_n) begin
        if (!rst_n)
            Fout <= 1'b0;
        else
            Fout <= (qn_o == ~Pi_correct | qn_o == ~(Pi_correct-1)) ? 1'b1 : 1'b0;
    end

endmodule
