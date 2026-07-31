`timescale 1ns / 1ps

module div_45 (
    input clk,
    input rst_n,
    input MC,    // MC = 0 时，4分频；MC = 1 时，5分频

    output f45
);

    wire D1;
    wire Q1, Qn1;
    wire D2;
    wire Q2, Qn2;
    wire D3;
    wire Q3, Qn3;

    // 4/5 分频器组合逻辑
    assign D1 = ~(Q2 & (Q3 | ~MC));  // MC=0: ~Q2 (4分频); MC=1: ~(Q2&Q3) (5分频)
    assign D2 = Q1;
    assign D3 = Q2;

    assign f45 = Qn3;  // 4/5 分频输出

    // D 触发器（3 个，去掉原来的 u4）
    reg_sync #( .WIDTH ( 1 )) u1_reg_sync (
        .clk   ( clk   ),
        .rst_n ( rst_n ),
        .D     ( D1    ),
        .Q     ( Q1    ),
        .Qn    ( Qn1   )
    );

    reg_sync #( .WIDTH ( 1 )) u2_reg_sync (
        .clk   ( clk   ),
        .rst_n ( rst_n ),
        .D     ( D2    ),
        .Q     ( Q2    ),
        .Qn    ( Qn2   )
    );

    reg_sync #( .WIDTH ( 1 )) u3_reg_sync (
        .clk   ( clk   ),
        .rst_n ( rst_n ),
        .D     ( D3    ),
        .Q     ( Q3    ),
        .Qn    ( Qn3   )
    );

endmodule
