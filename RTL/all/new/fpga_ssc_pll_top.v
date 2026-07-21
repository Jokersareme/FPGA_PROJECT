`timescale 1ns / 1ps

// 修复:
// 1. and_rst_n_fracn 门控: locked_pll && sys_rst_n, MMCM未锁定时保持fractionaln复位,避免X态
// 2. div_cnt_cmp 修正为 ref_div_cnt_cmp (原代码未声明div_cnt_cmp)
module fpga_ssc_pll_top (
    input  wire sys_clk_p,      // 125MHz，必须来自 MMCM/BUFG
    input  wire sys_clk_n,      // 125MHz，必须来自 MMCM/BUFG
    input  wire sys_rst,
    output wire sma_dtc_p,      // 补偿通道（有 DTC）
    output wire sma_dtc_n
);
    wire sys_rst_n;
    wire sys_clk_i;
    wire sys_clk_g;
    wire div_out_dtc_b;
    wire div_out_dtc_g;
    wire div_out_raw_g;
    wire clk_out_pll;
    wire locked_pll;
    wire clk_fb_pll;
    wire clk_ref_pll;
    wire clk_fb_pll_raw;
    wire [8:0] dtc_code;
    wire       dtc_load;
    wire div_out_dtc;
    wire idelay_rdy;
    wire sys_clk;
    wire clk_300m;
    wire [7:0]  int_div            ;
    wire [9:0]  frac               ;
    wire [7:0]  dtc_gain           ;
    wire        dtc_en             ;
    wire [8:0]  dtc_offset         ;
    wire [2:0]  clk_sel_0          ;
    wire [2:0]  clk_sel_1          ;
    wire [9:0]        mash_e1;
    wire              div_out_raw;
    wire clk_mux_01;
    wire clk_mux_02;
    wire bgmux_out2;
    wire bgmux_out3;
    wire test_clk_out;
    reg [3:0] div_cnt;
    wire [9:0] ref_div_cnt_cmp;
    reg clk_div10;

    wire cal_mode;
    wire [8:0] cal_result;
    wire cal_valid;

    wire rst_n_fracn;
    wire rst_n_mmcm;
    wire rst_n_dtc;
    wire and_rst_n_fracn;
    wire and_rst_n_mmcm;
    wire and_rst_n_dtc;

    wire div_out_dtc_0;
    wire div_out_dtc_1;
    wire div_out_dtc_2;
    wire div_out_dtc_3;

    // ============================================================
    // 修复: fractionaln 复位门控 locked_pll
    // MMCM 未锁定时 clk_out_pll 不稳定 → 保持 fractionaln 复位
    // 替代原 ss_cnt 延迟的功能(消除仿真 X 态),且不引入毛刺
    // ============================================================
    assign and_rst_n_fracn = locked_pll && sys_rst_n;
    assign and_rst_n_mmcm  = 1'b1       && sys_rst_n;
    assign and_rst_n_dtc   = 1'b1       && sys_rst_n;

    always @(posedge sys_clk_g or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            div_cnt   <= 4'd0;
            clk_div10 <= 1'b0;
        end else if (div_cnt == ref_div_cnt_cmp) begin  // 修复: 原为未声明的 div_cnt_cmp
            div_cnt   <= 4'd0;
            clk_div10 <= ~clk_div10;
        end else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end

    assign sys_rst_n = ~sys_rst;

       IBUFDS #(
      .DIFF_TERM("FALSE"),
      .IBUF_LOW_PWR("FALSE"),
      .IOSTANDARD("LVDS")
   ) IBUFDS_inst_clk125 (
      .O(sys_clk_i),
      .I(sys_clk_p),
      .IB(sys_clk_n)
   );

    BUFG u_sys_bufg_0 (.I (sys_clk_i), .O (sys_clk_g));
    BUFG u_sys_bufg_2 (.I (clk_div10), .O (clk_ref_pll));

    // -------------------------------------------------------------------------
    // 1. VIO 控制信号
    // -------------------------------------------------------------------------
    vio_0 u_vio (
        .clk        (sys_clk_g),
        .probe_in0  (idelay_rdy),
        .probe_in1  (locked_pll),
        .probe_out0 (int_div),
        .probe_out1 (frac),
        .probe_out2 (dtc_gain),
        .probe_out3 (dtc_en),
        .probe_out4 (ref_div_cnt_cmp),
        .probe_out5 (dtc_offset),
        .probe_out6 (cal_mode)
    );

    vio_rst u_vio_rst (
      .clk(sys_clk_g),
      .probe_out0(rst_n_fracn),
      .probe_out1(rst_n_mmcm),
      .probe_out2(rst_n_dtc),
      .probe_out3()
    );

    test_clk u_vio_test_clk (
        .clk        (sys_clk_g),
        .probe_out0 (clk_sel_0),
        .probe_out1 (clk_sel_1)
    );

    BUFG u_sys_bufg_fracn_out (.I (div_out_raw), .O (div_out_raw_g));

    // -------------------------------------------------------------------------
    // 2. MASH111 + 小数分频
    // -------------------------------------------------------------------------
    fractionaln  u_fracn_div (
        .Fin         (clk_out_pll  ),
        .Sys_clk     (sys_clk_g  ),
        .rst_n       (and_rst_n_fracn  ),
        .Integer     (int_div    ),
        .Fraction    (frac       ),
        .Eo          (mash_e1    ),
        .Fout        (div_out_raw)
    );

    // -------------------------------------------------------------------------
    // 3. DTC 补偿控制
    // -------------------------------------------------------------------------
    dtc_comp #(.WIDTH(10), .DTC_WIDTH(9)) u_dtc_ctrl (
        .clk             (sys_clk_g),
        .rst_n           (rst_n_dtc),
        .e1              (mash_e1),
        .dtc_gain        (dtc_gain),
        .dtc_en          (dtc_en),
        .dtc_offset      (dtc_offset),
        .dtc_code        (dtc_code),
        .dtc_load        (dtc_load)
    );

    // -------------------------------------------------------------------------
    // 4. ILA 观测
    // -------------------------------------------------------------------------
    ila_0 u_ila (
        .clk    (sys_clk_g),
        .probe0 (div_out_raw_g),
        .probe1 (div_out_dtc_g),
        .probe2 (mash_e1),
        .probe3 ({1'b0,dtc_load,clk_ref_pll}),
        .probe4 (dtc_code),
        .probe5 (cal_result),
        .probe6 (cal_valid)
    );

    // -------------------------------------------------------------------------
    // 5. SMA 差分输出
    // -------------------------------------------------------------------------
    BUFG u_sys_bufg_4 (.I (div_out_dtc), .O (div_out_dtc_g));

    // -------------------------------------------------------------------------
    // 6. DTC 级联链 (lut_dtc x5)
    // -------------------------------------------------------------------------
    lut_dtc #(
    .N_TAP (512),
    .CODE_WIDTH (9)
) u_lut_dtc_0 (
             .sys_clk       (sys_clk_g),
             .rst_n         (rst_n_dtc),
             .din           (div_out_raw_g),
             .code          (dtc_code),
             .cal_mode      (cal_mode),
             .dout          (div_out_dtc_0),
             .cal_result    (cal_result),
             .cal_valid     (cal_valid)
    );

    lut_dtc #(
    .N_TAP (512),
    .CODE_WIDTH (9)
) u_lut_dtc_1 (
             .sys_clk       (sys_clk_g),
             .rst_n         (rst_n_dtc),
             .din           (div_out_dtc_0),
             .code          (dtc_code),
             .cal_mode      (cal_mode),
             .dout          (div_out_dtc_1),
             .cal_result    (cal_result),
             .cal_valid     (cal_valid)
    );

    lut_dtc #(
.N_TAP (512),
    .CODE_WIDTH (9)
) u_lut_dtc_2 (
             .sys_clk       (sys_clk_g),
             .rst_n         (rst_n_dtc),
             .din           (div_out_dtc_1),
             .code          (dtc_code),
             .cal_mode      (cal_mode),
             .dout          (div_out_dtc_2),
             .cal_result    (cal_result),
             .cal_valid     (cal_valid)
    );

lut_dtc #(
    .N_TAP (512),
    .CODE_WIDTH (9)
) u_lut_dtc_3 (
             .sys_clk       (sys_clk_g),
             .rst_n         (rst_n_dtc),
             .din           (div_out_dtc_2),
             .code          (dtc_code),
             .cal_mode      (cal_mode),
             .dout          (div_out_dtc_3),
             .cal_result    (cal_result),
             .cal_valid     (cal_valid)
    );

lut_dtc #(
    .N_TAP (512),
    .CODE_WIDTH (9)
) u_lut_dtc_4 (
             .sys_clk       (sys_clk_g),
             .rst_n         (rst_n_dtc),
             .din           (div_out_dtc_3),
             .code          (dtc_code),
             .cal_mode      (cal_mode),
             .dout          (div_out_dtc),
             .cal_result    (cal_result),
             .cal_valid     (cal_valid)
    );

    // -------------------------------------------------------------------------
    // 7. MMCM/PLL
    // -------------------------------------------------------------------------
    clk_wiz_0 u_mmcm_pll (
        .reset      (~and_rst_n_mmcm ),
        .clk_in1    (clk_ref_pll),
        .clkfb_in     (clk_fb_pll ),
        .clk_out1   (clk_out_pll),
        .clkfb_out     (clk_fb_pll_raw),
        .locked     (locked_pll)
    );

    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_pll_ref (
        .O  (clk_fb_pll),
        .I0 (clk_fb_pll_raw),
        .I1 (div_out_dtc_g),
        .S  (clk_sel_1[2])
    );

    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_pll_01 (
        .O  (bgmux_out2),
        .I0 (clk_fb_pll_raw),
        .I1 (clk_out_pll),
        .S  (clk_sel_1[0])
    );

    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_pll_02 (
        .O  (bgmux_out3),
        .I0 (bgmux_out2),
        .I1 (div_out_dtc_g),
        .S  (clk_sel_1[1])
    );

    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_01 (
        .O  (clk_mux_01),
        .I0 (clk_ref_pll),
        .I1 (clk_fb_pll),
        .S  (clk_sel_0[0])
    );

    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_02 (
        .O  (clk_mux_02),
        .I0 (clk_mux_01),
        .I1 (div_out_raw_g),
        .S  (clk_sel_0[1])
    );

    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_out (
        .O  (test_clk_out),
        .I0 (clk_mux_02),
        .I1 (bgmux_out3),
        .S  (clk_sel_0[2])
    );

   OBUFDS #(
      .IOSTANDARD("LVDS"),
      .SLEW("FAST")
   ) OBUFDS_inst (
      .O(sma_dtc_p),
      .OB(sma_dtc_n),
      .I(test_clk_out)
   );

endmodule
