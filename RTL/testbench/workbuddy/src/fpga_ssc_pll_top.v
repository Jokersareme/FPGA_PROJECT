`timescale 1ns / 1ps

module fpga_ssc_pll_top (
    input  wire sys_clk_p,      // 125MHz，必须来自 MMCM/BUFG
    input  wire sys_clk_n,      // 125MHz，必须来自 MMCM/BUFG
    input  wire sys_rst,
//    input  wire clk_300m_p,       // 300MHz，给 IDELAYCTRL，必须来自 MMCM/BUFG
//    input  wire clk_300m_n,       // 300MHz，给 IDELAYCTRL，必须来自 MMCM/BUFG
    output wire sma_ref_p,      // 参考通道
    output wire sma_ref_n,
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
    reg  [8:0] dtc_code_d1 = 0;
    wire       dtc_load;
    wire div_out_dtc;
    wire idelay_rdy;  
    wire sys_clk;
    wire clk_300m;
//    wire clk_300m_g;
    wire [7:0]  int_div            ;
    wire [7:0]  ssc_int_div        ;
    wire [9:0]  frac               ;
    wire [9:0]  ssc_frac           ;
    wire [9:0]  dtc_gain           ;
    wire        dtc_en             ;
    wire [8:0]  dtc_offset         ;
    wire [2:0]  clk_sel_0          ; //debug_1 clk out sel [2] for change to clk_sel_1 debug
    wire [2:0]  clk_sel_1          ; //[2] for sel pll ref, [1,0] for sel debug_2 out
    wire [9:0]        mash_e1;
    wire [11:0]       mash_e_combined;   // 3 阶组合误差 (13-bit signed)
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
    wire [8:0] dtc_code_cal;       // 校准器输出的 dtc_code
    wire [9:0] dtc_gain_cal;       // 校准器计算的增益
    wire       cal_done;            // 校准完成
    wire       cal_start;           // 校准触发
    wire       cal_auto_en;         // 0=手动, 1=自动校准
    wire       order_sel;           // 0=1阶补偿, 1=3阶补偿
    wire [11:0] mash_e_dtc;          // 经 MUX 选通的误差 (送 dtc_comp)
    wire       cal_mode_int;        // 校准器内部 cal_mode
    wire [9:0] dtc_gain_muxed;      // 自动/手动增益选择
    
    wire rst_n_fracn;
    wire rst_n_mmcm;
    wire rst_n_dtc;
    wire and_rst_n_fracn;
    wire and_rst_n_mmcm;
    wire and_rst_n_dtc;
    
    wire dtc_sel;
    wire ssc_bp;
    
    wire       idelay_en;              // 0=CARRY8, 1=IDELAYE3
    wire       idelay_clk;             // IDELAYE3 clock
    wire       idelay_load;            // IDELAYE3 LOAD
    assign idelay_clk = sys_clk_g;
    assign idelay_en  = 1'b0;           // 默认 CARRY8（可通过 VIO 控制）
    
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

    // -------------------------------------------------------------------------
    // 1b. VIO 校准控制 (新增)
    // -------------------------------------------------------------------------
    vio_cal u_vio_cal (
        .clk        (sys_clk_g),
        .probe_out0 (cal_start),        // 上升沿触发校准
        .probe_out1 (cal_auto_en),      // 0=手动, 1=自动
        .probe_out2 (order_sel),        // 0=1阶补偿, 1=3阶补偿
        .probe_in0  (dtc_gain_cal),     // 校准结果: 修正增益
        .probe_in1  (cal_done)          // 校准完成标志
    );

    
    vio_rst u_vio_rst (
      .clk(sys_clk_g),                // input wire clk
      .probe_out0(rst_n_fracn),  // output wire [0 : 0] probe_out0
      .probe_out1(ssc_bp),  // output wire [0 : 0] probe_out1
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
    // 2. MASH111 + 小数分频 + SSC
    // -------------------------------------------------------------------------

    ssc_controller u_ssc_ctrl (
    .clk        (div_out_raw_g),     
    .rst_n      (and_rst_n_fracn),   
    .bypass     (ssc_bp),  
            
    .Integer    (int_div), 
    .Fraction   (frac),
          
    .ssc_int    (ssc_int_div), 
    .ssc_frac   (ssc_frac),
    .ssc_en     ()
    
    );


    fractionaln  u_fracn_div (
        .Fin         (clk_out_pll  ),
        .Sys_clk     (sys_clk_g  ),
        .rst_n       (and_rst_n_fracn  ),
        .Integer     (ssc_int_div    ),
        .Fraction    (ssc_frac       ),
        .Eo              (mash_e1),
        .E_combined      (mash_e_combined),

        .Fout        (div_out_raw)
                  
    );

    // -------------------------------------------------------------------------
    // 3. DTC 补偿控制
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // 3a. 校准器 (新增)
    // -------------------------------------------------------------------------
    // dtc_sel = order_sel: 1阶→1级链(~2ns), 3阶→4级链(~8ns)
    // VIO 的 dtc_sel 不再使用, 由 order_sel 直接控制
    dtc_calibrator #(.SHIFT(11)) u_cal (
        .clk            (sys_clk_g),
        .order_sel      (order_sel),    // 自动切换 K 常数
        .rst_n          (rst_n_dtc),
        .cal_mode_ext   (cal_start),
        .cal_mode       (cal_mode_int),
        .cal_result     (cal_result),
        .cal_valid      (cal_valid),
        .dtc_code_cal   (dtc_code_cal),
        .dtc_gain_cal   (dtc_gain_cal),
        .cal_done       (cal_done),
        .tdc_min        (),
        .tdc_max        ()
    );

    // -------------------------------------------------------------------------
    // 3b. 模式选择 & 校准路径分离
    // -------------------------------------------------------------------------
    // cal_mode: 自动模式走校准器, 手动模式走 VIO
    // dtc_code: 主延迟链始终走 dtc_comp 的输出
    // dtc_code_cal: 校准延迟链走校准器的 code（与主路径独立）
    wire cal_mode_sel;

    assign cal_mode_sel = cal_auto_en ? cal_mode_int : cal_mode;

    // dtc_code_pipe: 在 Fout 域打一拍, 避免 dtc_comp 组合输出直接进 dtc_code_d1
    //   posedge Fout 捕获: 1阶的 Eo(posedge更新) 采到旧值(正确)
    //                       3阶的 E_combined(negedge更新) 已传播半个周期(稳定)
    //   再经 dtc_code_d1(negedge div_out_dtc_g) 捕获, 隔半个Fout周期, 安全
    reg [8:0] dtc_code_pipe = 0;
    always @(posedge div_out_raw_g or negedge rst_n_dtc) begin
        if (!rst_n_dtc)
            dtc_code_pipe <= 9'd0;
        else
            dtc_code_pipe <= dtc_code;
    end

    // -------------------------------------------------------------------------
    // 3c. DTC 补偿阶数选择
    // -------------------------------------------------------------------------
    // order_sel = 0: 1 阶补偿 (Eo = e1[n-1], 10-bit unsigned → 零扩展)
    // order_sel = 1: 3 阶补偿 (E_combined, 12-bit signed)
    assign mash_e_dtc = order_sel ? $signed(mash_e_combined) : $signed({2'b0, mash_e1});

    // 增益 MUX: 自动模式走校准器, 手动模式走 VIO
    assign dtc_gain_muxed = cal_auto_en ? dtc_gain_cal : dtc_gain;

    // SHIFT=11: 必须与 dtc_calibrator 的 SHIFT 一致
    //   (SHIFT=12 时 K_BASE=32704, 1635 装不进 10-bit gain)
    // offset 自动居中: 3阶加 256, 1阶不加 (由 dtc_comp 内部处理)
    dtc_comp #(.WIDTH(12), .SHIFT(10), .DTC_WIDTH(9)) u_dtc_ctrl (
        .clk             (sys_clk_g),
        .rst_n           (rst_n_dtc),
        .e1              (mash_e_dtc),
        .dtc_gain        (dtc_gain_muxed),
        .dtc_en          (dtc_en),
        .dtc_offset      (dtc_offset),
        .order_sel       (order_sel),
        .dtc_code        (dtc_code),
        .dtc_load        (dtc_load)
    );



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
        .probe3 ({cal_done, cal_auto_en, dtc_load}),
        .probe4 (dtc_code_pipe),
        .probe5 (cal_result),
        .probe6 ({cal_valid, cal_done, cal_start, 5'd0})
    );

//     -------------------------------------------------------------------------
//     6. SMA 差分输出（直接驱动顶层端口，无内部 assign） 
//      TO ADI PLL
//     -------------------------------------------------------------------------
    OBUFDS #(
        .IOSTANDARD("LVDS"),
        .SLEW("FAST")
    ) u_obuf_ref (
        .O  (sma_ref_p),
        .OB (sma_ref_n),
        .I  (div_out_dtc_g)
    );
    

    

    always @(posedge ~div_out_dtc_g or negedge rst_n_dtc) begin
        if (!rst_n_dtc)
            dtc_code_d1 <= 1'b0;
        else 
            dtc_code_d1 <= dtc_code_pipe;
    end
    
    lut_dtc_top #(
    .N_TAP (512),
    .CODE_WIDTH (9)
) u_lut_dtc_top (
             .sys_clk       (sys_clk_g),
             .rst_n         (rst_n_dtc),
             .din           (div_out_raw_g),
             .code          (dtc_code_d1),
             .cal_code      (dtc_code_cal),
             .cal_mode      (cal_mode_sel),
             .dtc_sel       (order_sel),
             .vco_clk       (clk_out_pll),
             .idelay_en     (idelay_en),
             .idelay_clk    (idelay_clk),
             .idelay_load   (idelay_load),
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
