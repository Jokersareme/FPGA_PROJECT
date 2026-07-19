`timescale 1ns / 1ps

module fpga_ssc_pll_top (
    input  wire sys_clk_p,      // 125MHz，必须来自 MMCM/BUFG
    input  wire sys_clk_n,      // 125MHz，必须来自 MMCM/BUFG
    input  wire sys_rst,
//    input  wire clk_300m_p,       // 300MHz，给 IDELAYCTRL，必须来自 MMCM/BUFG
//    input  wire clk_300m_n,       // 300MHz，给 IDELAYCTRL，必须来自 MMCM/BUFG
//    output wire sma_ref_p,      // 参考通道（无补偿）
//    output wire sma_ref_n,
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
//    wire clk_300m_g;
    wire [7:0]  int_div            ;
    wire [9:0]  frac               ;
    wire [7:0]  dtc_gain           ;
    wire        dtc_en             ;
    wire [8:0]  dtc_offset         ;
    wire [2:0]  clk_sel_0          ; //debug_1 clk out sel [2] for change to clk_sel_1 debug
    wire [2:0]  clk_sel_1          ; //[2] for sel pll ref, [1,0] for sel debug_2 out
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
    
    wire dtc_sel;
    
    assign and_rst_n_fracn =   1'b1   &&   sys_rst_n;
    assign and_rst_n_mmcm =    1'b1   &&   sys_rst_n;
    assign and_rst_n_dtc =     1'b1   &&   sys_rst_n;
    
    always @(posedge sys_clk_g or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            div_cnt      <= 4'd0;
            clk_div10 <= 1'b0;
        end else if (div_cnt == ref_div_cnt_cmp) begin
            div_cnt      <= 4'd0;
            clk_div10 <= ~clk_div10;
        end else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end
    
    
    assign sys_rst_n = ~sys_rst;
    
       IBUFDS #(
      .DIFF_TERM("FALSE"),       // Differential Termination
      .IBUF_LOW_PWR("FALSE"),     // Low power="TRUE", Highest performance="FALSE" 
      .IOSTANDARD("LVDS")     // Specify the input I/O standard
   ) IBUFDS_inst_clk125 (
      .O(sys_clk_i),  // Buffer output
      .I(sys_clk_p),  // Diff_p buffer input (connect directly to top-level port)
      .IB(sys_clk_n) // Diff_n buffer input (connect directly to top-level port)
   );
//       IBUFDS #(
//      .DIFF_TERM("FALSE"),       // Differential Termination
//      .IBUF_LOW_PWR("FALSE"),     // Low power="TRUE", Highest performance="FALSE" 
//      .IOSTANDARD("LVDS")     // Specify the input I/O standard
//   ) IBUFDS_inst_clk_300 (
//      .O(clk_300m),  // Buffer output
//      .I(clk_300m_p),  // Diff_p buffer input (connect directly to top-level port)
//      .IB(clk_300m_n) // Diff_n buffer input (connect directly to top-level port)
//   );
    
    BUFG u_sys_bufg_0 (.I (sys_clk_i), .O (sys_clk_g));
//    BUFG u_sys_bufg_1 (.I (clk_300m), .O (clk_300m_g));
    BUFG u_sys_bufg_2 (.I (clk_div10), .O (clk_ref_pll));
    
    // -------------------------------------------------------------------------
    // 1. VIO 控制信号
    // -------------------------------------------------------------------------

    // 解析 VIO 输出


    vio_0 u_vio (
        .clk        (sys_clk_g),
        .probe_in0  (idelay_rdy),      // 接 IDELAYCTRL 就绪状态
        .probe_in1  (locked_pll),      // 接 pll_locked 就绪状态
        .probe_out0 (int_div),     // 8-bit
        .probe_out1 (frac),     // 10-bit
        .probe_out2 (dtc_gain),      // 8-bit
        .probe_out3 (dtc_en),      // 1-bit
        .probe_out4 (ref_div_cnt_cmp),      // 10-bit
        .probe_out5 (dtc_offset),      // 9-bit
        .probe_out6 (cal_mode)      // 9-bit
        
    );
    
    
    vio_rst u_vio_rst (
      .clk(sys_clk_g),                // input wire clk
      .probe_out0(rst_n_fracn),  // output wire [0 : 0] probe_out0
      .probe_out1(rst_n_mmcm),  // output wire [0 : 0] probe_out1
      .probe_out2(rst_n_dtc),  // output wire [0 : 0] probe_out2
      .probe_out3(dtc_sel)  // output wire [0 : 0] probe_out3
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
        //.dtc_offset_sel  (dtc_offset_sel),
        .dtc_en          (dtc_en),
		.dtc_offset      (dtc_offset),
        .dtc_code        (dtc_code),
        .dtc_load        (dtc_load)
    );

    // -------------------------------------------------------------------------
    // 4. IDELAYE3 延迟线（补偿通道）
    // -------------------------------------------------------------------------
// (* IODELAY_GROUP = "DTC_GRP" *)
//IDELAYE3 #(
//    .CASCADE          ("NONE"),
//    .DELAY_FORMAT     ("TIME"),          // 模板指定
//    .DELAY_SRC        ("DATAIN"),       // 从内部逻辑输入（div_out_raw 是内部信号）
//    .DELAY_TYPE       ("VAR_LOAD"),
//    .DELAY_VALUE      (256),
//    .IS_CLK_INVERTED  (1'b0),
//    .IS_RST_INVERTED  (1'b0),
//    .REFCLK_FREQUENCY (125.0),          // ⚠️ 必须和 clk_300m 实际频率一致！
//    .SIM_DEVICE       ("ULTRASCALE_PLUS"),
//    .UPDATE_MODE      ("M_SYNC")
//) u_idelaye3 (
//    .CLK         (sys_clk_g),
//    .CE          (1'b0),
//    .CASC_IN     (1'b0),
//    .CASC_RETURN (1'b0),
//    .IDATAIN      (1'b0),                // 不用 IDATAIN 路径，接地
//    .DATAIN     (div_out_raw_g),         // 内部信号走 DATAIN
//    .INC         (1'b0),
//    .LOAD        (dtc_load),            // 模板端口名是 LOAD
//    .CNTVALUEIN  (dtc_code),
//    .CNTVALUEOUT (),
//    .DATAOUT     (div_out_dtc),
//    .CASC_OUT    (),
//    .EN_VTC      (1'b1),                // 不单独使能 VTC，由 IDELAYCTRL 统一处理
//    .RST         (~sys_rst_n)
//);

//(* IODELAY_GROUP = "DTC_GRP" *)
//IDELAYCTRL #(    .SIM_DEVICE       ("ULTRASCALE"))
//u_idelayctrl (
//    .REFCLK (sys_clk_g),
//    .RST    (~sys_rst_n),
//    .RDY    (idelay_rdy)
//);


//assign div_out_dtc_b = ~div_out_dtc & sys_rst_n;
//assign div_out_dtc_g = ~div_out_dtc_b;
BUFG u_sys_bufg_4 (.I (div_out_dtc), .O (div_out_dtc_g));
//BUFG u_sys_bufg_5 (.I (div_out_raw), .O (div_out_raw_g));
    // -------------------------------------------------------------------------
    // 5. ILA 观测
    // -------------------------------------------------------------------------
    ila_0 u_ila (
        .clk    (sys_clk_g),
        .probe0 (div_out_raw_g),
        .probe1 (div_out_dtc_g),
        .probe2 (mash_e1),
        .probe3 ({1'b0,dtc_load,clk_ref_pll}),  // 3-bit 扩展为 4-bit 匹配 ILA 宽度，或按实际 ILA 配置调整
        .probe4 (dtc_code),  // 3-bit 扩展为 4-bit 匹配 ILA 宽度，或按实际 ILA 配置调整
        .probe5 (cal_result),  // 3-bit 扩展为 4-bit 匹配 ILA 宽度，或按实际 ILA 配置调整
        .probe6 (cal_valid)  // 3-bit 扩展为 4-bit 匹配 ILA 宽度，或按实际 ILA 配置调整
    );

    // -------------------------------------------------------------------------
    // 6. SMA 差分输出（直接驱动顶层端口，无内部 assign）
    // -------------------------------------------------------------------------
//    OBUFDS #(
//        .IOSTANDARD("LVDS"),
//        .SLEW("FAST")
//    ) u_obuf_ref (
//        .O  (sma_ref_p),
//        .OB (sma_ref_n),
//        .I  (bgmux_out2)
//    );
    


    lut_dtc #(
    .N_TAP (512),
    .CODE_WIDTH (9)
) u_lut_dtc_0 (
             .sys_clk       (sys_clk_g),
             .rst_n         (rst_n_dtc),
             .din           (div_out_raw_g),
             .code          (dtc_code),
             .cal_mode      (cal_mode),
             .dtc_sel       (dtc_sel),
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
             .dtc_sel       (dtc_sel),
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
             .dtc_sel       (dtc_sel),
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
             .dtc_sel       (dtc_sel),
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
             .dtc_sel       (dtc_sel),
             .dout          (div_out_dtc),
             .cal_result    (cal_result),
             .cal_valid     (cal_valid)
    );
    
    
    //PLL
    clk_wiz_0 u_mmcm_pll (
        //input
        .reset      (~and_rst_n_mmcm ),
        .clk_in1    (clk_ref_pll),
        .clkfb_in     (clk_fb_pll ),
        //output
        .clk_out1   (clk_out_pll),
        .clkfb_out     (clk_fb_pll_raw),
        .locked     (locked_pll)
        
    );
    
        
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")   // 同步切换，毛刺更小
    ) u_mux_pll_ref (
        .O  (clk_fb_pll),
        .I0 (clk_fb_pll_raw),            // 必须来自 BUFG 输出
        .I1 (div_out_dtc_g),            // 必须来自 BUFG 输出
        .S  (clk_sel_1[2])        // 0=clk0, 1=clk1
    );
    
    
    // 输入时钟必须都来自全局网络（BUFG/MMCM/PLL 输出）
    // PLL REF SEL
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")   // 同步切换，毛刺更小
    ) u_mux_pll_01 (
        .O  (bgmux_out2),
        .I0 (clk_fb_pll_raw),            // 必须来自 BUFG 输出
        .I1 (clk_out_pll),            // 必须来自 BUFG 输出
        .S  (clk_sel_1[0])        // 0=clk0, 1=clk1
    );
    
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")   // 同步切换，毛刺更小
    ) u_mux_pll_02 (
        .O  (bgmux_out3),
        .I0 (bgmux_out2),            // 必须来自 BUFG 输出
        .I1 (div_out_dtc_g),            // 必须来自 BUFG 输出
        .S  (clk_sel_1[1])        // 0=clk0, 1=clk1
    );
    
    // 第一级：clk0 vs clk1
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")   // 同步切换，毛刺更小
    ) u_mux_01 (
        .O  (clk_mux_01),
        .I0 (clk_ref_pll),            // 必须来自 BUFG 输出
        .I1 (clk_fb_pll),            // 必须来自 BUFG 输出
        .S  (clk_sel_0[0])        // 0=clk0, 1=clk1
    );
    
    // 第二级：前级输出 vs clk2
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_02 (
        .O  (clk_mux_02),
        .I0 (clk_mux_01),       // 前级结果
        .I1 (div_out_raw_g),            // 必须来自 BUFG 输出
        .S  (clk_sel_0[1])        // 0=前级结果, 1=clk2
    );

    // 第二级：前级输出 vs clk2
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_out (
        .O  (test_clk_out),
        .I0 (clk_mux_02),       // 前级结果
        .I1 (bgmux_out3),            // 必须来自 BUFG 输出
        .S  (clk_sel_0[2])        // 0=前级结果, 1=clk2
    );
    
    
    
    
   OBUFDS #(
      .IOSTANDARD("LVDS"), // Specify the output I/O standard
      .SLEW("FAST")           // Specify the output slew rate
   ) OBUFDS_inst (
      .O(sma_dtc_p),     // Diff_p output (connect directly to top-level port)
      .OB(sma_dtc_n),   // Diff_n output (connect directly to top-level port)
      .I(test_clk_out)      // Buffer input
   );



endmodule
