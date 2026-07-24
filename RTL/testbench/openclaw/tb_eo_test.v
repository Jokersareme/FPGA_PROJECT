`timescale 1ns / 1ps
// 测试 fractionaln 在不同 eo_dly_sel 下的 E_combined 输出
module tb_eo_test;
    reg Fin, Sys_clk, rst_n;
    reg [7:0] Integer;
    reg [9:0] Fraction;
    wire [9:0] Eo;
    wire [12:0] E_combined;
    wire Fout;

    fractionaln #(.P_WIDTH(6), .S_WIDTH(2), .INT_WIDTH(8), .FRAC_WIDTH(10))
    u_fracn (.Fin(Fin), .Sys_clk(Sys_clk), .rst_n(rst_n),
             .Integer(Integer), .Fraction(Fraction),
             .Eo(Eo), .E_combined(E_combined), .Fout(Fout));

    always #0.8 Fin = ~Fin;       // 625MHz
    always #4 Sys_clk = ~Sys_clk;  // 125MHz

    initial begin
        $dumpfile("tb_eo_test.vcd");
        $dumpvars(1, Fin, Sys_clk, rst_n, Fout);
        $dumpvars(1, u_fracn.e3_r1, u_fracn.e3_r2, u_fracn.e3_r3);
        $dumpvars(1, u_fracn.comp_3rd);
        $dumpvars(1, E_combined, Eo);
        $dumpvars(1, u_fracn.Ec_d1, u_fracn.Ec_d2, u_fracn.Ec_d3);
        $dumpvars(1, u_fracn.eo_dly_sel);
        $dumpvars(1, u_fracn.u_mash111.e_o_1);
        $dumpvars(1, u_fracn.u_mash111.e_o_2);
        $dumpvars(1, u_fracn.u_mash111.e_o_3);
    end

    initial begin
        Fin = 0; Sys_clk = 0; rst_n = 0;
        Integer = 71; Fraction = 213;
        #200 rst_n = 1;
        #100000;
        $display("@%0t: DONE", $time);
        $display("E_combined last=%0d eo_dly_sel=%0d", E_combined, u_fracn.eo_dly_sel);
        $finish;
    end
endmodule
