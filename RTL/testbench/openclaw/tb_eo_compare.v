`timescale 1ns / 1ps
// eo_dly_sel 测试 — 直接模拟 fractionaln 的 E_combined 选择逻辑
module tb_eo_compare;
    reg clk, rst_n;
    reg [1:0] eo_dly_sel;
    reg [9:0] e3_in;
    
    // 模拟 fractionaln 内部 pipeline
    reg  [9:0] e3_r1=0, e3_r2=0, e3_r3=0;
    wire [12:0] comp_3rd;
    reg  [12:0] Ec_d1=0, Ec_d2=0, Ec_d3=0;
    reg  [12:0] E_combined=0;
    
    assign comp_3rd = $signed({2'b0, e3_r1})
                    - $signed({1'b0, e3_r2, 1'b0})
                    + $signed({2'b0, e3_r3});
    
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            e3_r1 <= 0; e3_r2 <= 0; e3_r3 <= 0;
            Ec_d1 <= 0; Ec_d2 <= 0; Ec_d3 <= 0;
            E_combined <= 0;
        end else begin
            e3_r1 <= e3_in; e3_r2 <= e3_r1; e3_r3 <= e3_r2;
            Ec_d1 <= comp_3rd;
            Ec_d2 <= Ec_d1;
            Ec_d3 <= Ec_d2;
            case (eo_dly_sel)
                2'd0: E_combined <= comp_3rd;
                2'd1: E_combined <= Ec_d1;
                2'd2: E_combined <= Ec_d2;
                2'd3: E_combined <= Ec_d3;
            endcase
        end
    end
    
    // MASH 风格的 e3 测试序列
    integer e3_seq[0:29];
    initial begin
        e3_seq[0] = 558;  e3_seq[1] = 169;  e3_seq[2] = 193;
        e3_seq[3] = 844;  e3_seq[4] = 287;  e3_seq[5] = 781;
        e3_seq[6] = 493;  e3_seq[7] = 658;  e3_seq[8] = 466;
        e3_seq[9] = 129;  e3_seq[10] = 884; e3_seq[11] = 897;
        e3_seq[12] = 379; e3_seq[13] = 567; e3_seq[14] = 651;
        e3_seq[15] = 843; e3_seq[16] = 332; e3_seq[17] = 354;
        e3_seq[18] = 99;  e3_seq[19] = 803; e3_seq[20] = 369;
        e3_seq[21] = 514; e3_seq[22] = 913; e3_seq[23] = 725;
        e3_seq[24] = 275; e3_seq[25] = 90;  e3_seq[26] = 211;
        e3_seq[27] = 784; e3_seq[28] = 446; e3_seq[29] = 490;
    end

    always #0.8 clk = ~clk;  // 625MHz

    integer i;
    initial begin
        $dumpfile("tb_eo_compare.vcd");
        $dumpvars(1, clk, rst_n, eo_dly_sel);
        $dumpvars(1, e3_in, e3_r1, e3_r2, e3_r3);
        $dumpvars(1, comp_3rd, Ec_d1, Ec_d2, Ec_d3, E_combined);
        
        clk = 0; rst_n = 0; e3_in = 0; eo_dly_sel = 0;
        #20 rst_n = 1;
        #10;
        e3_seq[0] = 558;  e3_seq[1] = 169;  e3_seq[2] = 193;
        e3_seq[3] = 844;  e3_seq[4] = 287;  e3_seq[5] = 781;
        e3_seq[6] = 493;  e3_seq[7] = 658;  e3_seq[8] = 466;
        e3_seq[9] = 129;  e3_seq[10] = 884; e3_seq[11] = 897;
        e3_seq[12] = 379; e3_seq[13] = 567; e3_seq[14] = 651;
        e3_seq[15] = 843; e3_seq[16] = 332; e3_seq[17] = 354;
        e3_seq[18] = 99;  e3_seq[19] = 803; e3_seq[20] = 369;
        e3_seq[21] = 514; e3_seq[22] = 913; e3_seq[23] = 725;
        e3_seq[24] = 275; e3_seq[25] = 90;  e3_seq[26] = 211;
        e3_seq[27] = 784; e3_seq[28] = 446; e3_seq[29] = 490;
        
        // 先跑 eo=0
        $display("=== eo_dly_sel=0 ===");
        for (i = 0; i < 30; i = i + 1) begin
            e3_in = e3_seq[i];
            @(posedge clk);
            if (i > 2) @(negedge clk); // 等 pipeline 更新
            if (i > 2)
                $display("  n=%0d: e3=%0d c3=%0d E_combined=%0d (eo=0)", 
                    i, e3_r1, comp_3rd, E_combined);
        end
        
        // 切到 eo=1 再跑
        #500;
        eo_dly_sel = 1;
        $display("");
        $display("=== eo_dly_sel=1 ===");
        for (i = 0; i < 30; i = i + 1) begin
            e3_in = e3_seq[i];
            @(posedge clk);
            if (i > 2) @(negedge clk);
            if (i > 2)
                $display("  n=%0d: e3=%0d c3=%0d E_combined=%0d (eo=1)",
                    i, e3_r1, comp_3rd, E_combined);
        end
        
        #500;
        $finish;
    end
endmodule
