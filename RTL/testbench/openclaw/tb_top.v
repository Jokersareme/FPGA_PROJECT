`timescale 1ns / 1ps
module tb_top;
    parameter SYS_CLK_PERIOD = 8.0;
    reg sys_clk_p = 0; reg sys_clk_n = 0; reg sys_rst;
    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;
    fpga_ssc_pll_top u_dut (
        .sys_clk_p(sys_clk_p), .sys_clk_n(sys_clk_n), .sys_rst(sys_rst),
        .sma_ref_p(sma_ref_p), .sma_ref_n(sma_ref_n),
        .sma_dtc_p(sma_dtc_p), .sma_dtc_n(sma_dtc_n));
    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;
    initial begin sys_rst = 0; #1 sys_rst = 1; #100 sys_rst = 0; end

    initial begin
        $dumpfile("tb_top_auto_full.vcd");
        $dumpvars(0, tb_top.u_dut.div_out_dtc_g);
        $dumpvars(0, tb_top.u_dut.div_out_raw_g);
        $dumpvars(0, tb_top.u_dut.dtc_code_d1);
        $dumpvars(0, tb_top.u_dut.dtc_gain_muxed);
        $dumpvars(0, tb_top.u_dut.cal_auto_en);
        $dumpvars(0, tb_top.u_dut.cal_done);
        $dumpvars(0, tb_top.u_dut.cal_start);
        $dumpvars(0, tb_top.u_dut.sys_clk_g);
        $dumpvars(0, tb_top.u_dut.clk_ref_pll);
        $dumpvars(0, tb_top.u_dut.u_cal.state);
        $dumpvars(0, tb_top.u_dut.u_cal.next);
        $dumpvars(0, tb_top.u_dut.u_cal.tdc_min);
        $dumpvars(0, tb_top.u_dut.u_cal.tdc_max);
        $dumpvars(0, tb_top.u_dut.u_cal.cal_mode);
        $dumpvars(0, tb_top.u_dut.u_cal.cal_valid);
        $dumpvars(0, tb_top.u_dut.u_cal.cal_result);
        $dumpvars(0, tb_top.u_dut.u_cal.dtc_code_cal);
        $dumpvars(0, tb_top.u_dut.u_cal.dtc_gain_cal);
        $dumpvars(0, tb_top.u_dut.u_cal.wait_cnt);
        $dumpvars(0, tb_top.u_dut.u_cal.div_busy);
        $dumpvars(0, tb_top.u_dut.u_cal.dividend);
        $dumpvars(0, tb_top.u_dut.u_cal.divisor);
        $dumpvars(0, tb_top.u_dut.u_cal.quotient);
        $dumpvars(0, tb_top.u_dut.u_cal.div_cnt);
        $dumpvars(0, tb_top.u_dut.u_fracn_div.mash_e1);
        $dumpvars(0, tb_top.u_dut.u_fracn_div.mash_e2);
        $dumpvars(0, tb_top.u_dut.u_fracn_div.mash_e3);
        $dumpvars(0, tb_top.dtc_dly);
    end

    initial begin #1;
        force u_dut.u_fracn_div.u_mash111.stage_sel = 2'b01;
        force u_dut.u_fracn_div.eo_dly_sel = 2'b01;
        force u_dut.order_sel = 1'b0;
        force u_dut.locked_pll = 1'b1;
        force u_dut.and_rst_n_dtc = 1'b1;
        force u_dut.cal_auto_en = 1'b1;
        #200 force u_dut.u_cal.next = 4'd1;
        #10  force u_dut.u_cal.next = 4'd2;
        #10  force u_dut.u_cal.cal_valid = 1'b1; force u_dut.u_cal.cal_result = 9'd0;
        #2   force u_dut.u_cal.cal_valid = 1'b0;
        #10  force u_dut.u_cal.next = 4'd3;
        #10  force u_dut.u_cal.next = 4'd4;
        #10  force u_dut.u_cal.cal_valid = 1'b1;
        #2   force u_dut.u_cal.cal_valid = 1'b0;
        #10  force u_dut.u_cal.next = 4'd5;
        #10  force u_dut.u_cal.next = 4'd6;
        #10  force u_dut.u_cal.next = 4'd7;
        #10  force u_dut.u_cal.cal_valid = 1'b1; force u_dut.u_cal.cal_result = 9'd6;
        #2   force u_dut.u_cal.cal_valid = 1'b0;
        #10  force u_dut.u_cal.next = 4'd8;
        #10  force u_dut.u_cal.next = 4'd9;
        #10  force u_dut.u_cal.cal_valid = 1'b1;
        #2   force u_dut.u_cal.cal_valid = 1'b0;
        #10  force u_dut.u_cal.next = 4'd10;
        #10  force u_dut.u_cal.next = 4'd11;
        #120 force u_dut.u_cal.next = 4'd13;
        #20  release u_dut.u_cal.next; release u_dut.u_cal.cal_result;
    end

    reg dtc_dly = 0;
    always @(posedge u_dut.div_out_dtc_g) begin #(u_dut.dtc_code_d1 * 0.020); dtc_dly = 1; end
    always @(negedge u_dut.div_out_dtc_g) begin #(u_dut.dtc_code_d1 * 0.020); dtc_dly = 0; end

    initial begin
        #25000 $display("T=%0t: cal gain=%0d min=%0d max=%0d",
            $time, u_dut.dtc_gain_cal, u_dut.u_cal.tdc_min, u_dut.u_cal.tdc_max);
        #175000 $finish;
    end
endmodule
