`timescale 1ns / 1ps

module fpga_ssc_pll_top (
    input  wire sys_clk_p,      // 125MHz????? MMCM/BUFG
    input  wire sys_clk_n,      // 125MHz????? MMCM/BUFG
    input  wire sys_rst,
//    input  wire clk_300m_p,       // 300MHz?? IDELAYCTRL????? MMCM/BUFG
//    input  wire clk_300m_n,       // 300MHz?? IDELAYCTRL????? MMCM/BUFG
    output wire sma_ref_p,      // ????
    output wire sma_ref_n,
    output wire sma_dtc_p,      // ?????? DTC?
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
    reg [8:0] dtc_code_d1 = 0;
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
    wire [12:0]       mash_e_combined;   // 3 ????? (13-bit signed)
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
    wire [8:0] dtc_code_cal;       // ?????? dtc_code
    wire [9:0] dtc_gain_cal;       // ????????
    wire       cal_done;            // ????
    wire       cal_start;           // ????
    wire       cal_auto_en;         // 0=??, 1=????
    wire       order_sel;           // 0=1???, 1=3???
    wire [12:0] mash_e_dtc;          // ? MUX ????? (? dtc_comp)
    wire       cal_mode_int;        // ????? cal_mode
    wire [9:0] dtc_gain_muxed;      // ??/??????
    
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
    assign idelay_en  = 1'b0;           // ?? CARRY8???? VIO ???
    
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
    // 1. VIO ????
    // -------------------------------------------------------------------------

    // ?? VIO ??


    vio_0 u_vio (
        .clk        (sys_clk_g),
        .probe_in0  (idelay_rdy),      // ? IDELAYCTRL ????
        .probe_in1  (locked_pll),      // ? pll_locked ????
        .probe_out0 (int_div),     // 8-bit
        .probe_out1 (frac),     // 10-bit
        .probe_out2 (dtc_gain),      // 8-bit
        .probe_out3 (dtc_en),      // 1-bit
        .probe_out4 (ref_div_cnt_cmp),      // 10-bit
        .probe_out5 (dtc_offset),      // 9-bit
        .probe_out6 (cal_mode)      // 9-bit
        
    );

    // -------------------------------------------------------------------------
    // 1b. VIO ???? (??)
    // -------------------------------------------------------------------------
    vio_cal u_vio_cal (
        .clk        (sys_clk_g),
        .probe_out0 (cal_start),        // ???????
        .probe_out1 (cal_auto_en),      // 0=??, 1=??
        .probe_out2 (order_sel),        // 0=1???, 1=3???
        .probe_in0  (dtc_gain_cal),     // ????: ????
        .probe_in1  (cal_done)          // ??????
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
    // 2. MASH111 + ???? + SSC
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
    // 3. DTC ????
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // 3a. ??? (??)
    // -------------------------------------------------------------------------
    // dtc_sel = order_sel: 1??1??(~2ns), 3??4??(~8ns)
    // VIO ? dtc_sel ????, ? order_sel ????
    dtc_calibrator #(.SHIFT(11)) u_cal (
        .clk            (sys_clk_g),
        .order_sel      (order_sel),    // ???? K ??
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
    // 3b. ???? MUX
    // -------------------------------------------------------------------------
    // cal_auto_en = 0: ????
    //   cal_mode ? vio_0 ??, dtc_code ? dtc_comp ??
    // cal_auto_en = 1: ??????
    //   cal_mode ??????, dtc_code ??????
    wire cal_mode_sel;
    wire [8:0] dtc_code_muxed;

    assign cal_mode_sel = cal_auto_en ? cal_mode_int : cal_mode;
    // ???: ???? (cal_auto_en=1 ? cal_done=0)
    // ????: ???? dtc_comp (cal_done=1)
    assign dtc_code_muxed = (cal_auto_en && !cal_done) ? dtc_code_cal : dtc_code;

    // dtc_code_pipe: ? Fout ????, ?? dtc_comp ??????? dtc_code_d1
    //   posedge Fout ??: 1?? Eo(posedge??) ????(??)
    //                       3?? E_combined(negedge??) ???????(??)
    //   ?? dtc_code_d1(negedge div_out_dtc_g) ??, ???Fout??, ??
    reg [8:0] dtc_code_pipe = 0;
    always @(posedge div_out_raw_g or negedge rst_n_dtc) begin
        if (!rst_n_dtc)
            dtc_code_pipe <= 9'd0;
        else
            dtc_code_pipe <= dtc_code_muxed;
    end

    // -------------------------------------------------------------------------
    // 3c. DTC ??????
    // -------------------------------------------------------------------------
    // order_sel = 0: 1 ??? (Eo = e1[n-1], 10-bit unsigned ? ???)
    // order_sel = 1: 3 ??? (E_combined, 13-bit signed)
    assign mash_e_dtc = order_sel ? $signed(mash_e_combined) : $signed({3'b0, mash_e1});

    // ?? MUX: ????????, ????? VIO
    assign dtc_gain_muxed = cal_auto_en ? dtc_gain_cal : dtc_gain;

    // SHIFT=11: ??? dtc_calibrator ? SHIFT ??
    //   (SHIFT=12 ? K_BASE=32704, 1635 ??? 10-bit gain)
    // offset ????: 3?? 256, 1??? (? dtc_comp ????)
    dtc_comp #(.WIDTH(13), .SHIFT(11), .DTC_WIDTH(9)) u_dtc_ctrl (
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
    // 5. ILA ??
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
//     6. SMA ????????????????? assign? 
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
        .CLK_SEL_TYPE("SYNC")   // ?????????
    ) u_mux_pll_ref (
        .O  (clk_fb_pll),
        .I0 (clk_fb_pll_raw),            // ???? BUFG ??
        .I1 (div_out_dtc_g),            // ???? BUFG ??
        .S  (clk_sel_1[2])        // 0=clk0, 1=clk1
    );
    
    
    // ??????????????BUFG/MMCM/PLL ???
    // PLL REF SEL
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")   // ?????????
    ) u_mux_pll_01 (
        .O  (bgmux_out2),
        .I0 (clk_fb_pll_raw),            // ???? BUFG ??
        .I1 (clk_out_pll),            // ???? BUFG ??
        .S  (clk_sel_1[0])        // 0=clk0, 1=clk1
    );
    
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")   // ?????????
    ) u_mux_pll_02 (
        .O  (bgmux_out3),
        .I0 (bgmux_out2),            // ???? BUFG ??
        .I1 (div_out_dtc_g),            // ???? BUFG ??
        .S  (clk_sel_1[1])        // 0=clk0, 1=clk1
    );
    
    // ????clk0 vs clk1
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")   // ?????????
    ) u_mux_01 (
        .O  (clk_mux_01),
        .I0 (clk_ref_pll),            // ???? BUFG ??
        .I1 (clk_fb_pll),            // ???? BUFG ??
        .S  (clk_sel_0[0])        // 0=clk0, 1=clk1
    );
    
    // ???????? vs clk2
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_02 (
        .O  (clk_mux_02),
        .I0 (clk_mux_01),       // ????
        .I1 (div_out_raw_g),            // ???? BUFG ??
        .S  (clk_sel_0[1])        // 0=????, 1=clk2
    );

    // ???????? vs clk2
    BUFGMUX #(
        .CLK_SEL_TYPE("SYNC")
    ) u_mux_out (
        .O  (test_clk_out),
        .I0 (clk_mux_02),       // ????
        .I1 (bgmux_out3),            // ???? BUFG ??
        .S  (clk_sel_0[2])        // 0=????, 1=clk2
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
