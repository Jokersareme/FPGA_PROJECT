`timescale 1ns / 1ps

module fpga_ssc_pll_top (
    input  wire sys_clk_g,      // 125MHz，必须来自 MMCM/BUFG
    input  wire sys_rst_n,
    input  wire clk_300m,       // 300MHz，给 IDELAYCTRL，必须来自 MMCM/BUFG
    output wire sma_ref_p,      // 参考通道（无补偿）
    output wire sma_ref_n,
    output wire sma_dtc_p,      // 补偿通道（有 DTC）
    output wire sma_dtc_n
);

    // -------------------------------------------------------------------------
    // 1. VIO 控制信号
    // -------------------------------------------------------------------------
    wire [15:0] vio_out0;
    wire [10:0] vio_out1;
    wire        vio_in0;

    // 解析 VIO 输出
    wire [7:0]  int_div = vio_out0[15:8];
    wire [7:0]  frac    = vio_out0[7:0];
    wire [7:0]  dtc_gain = vio_out1[10:3];
    wire        dtc_en   = vio_out1[2];
    wire [1:0]  dtc_offset_sel = vio_out1[1:0];

    vio_0 u_vio (
        .clk        (sys_clk_g),
        .probe_in0  (vio_in0),      // 接 IDELAYCTRL 就绪状态
        .probe_out0 (vio_out0),     // 16-bit
        .probe_out1 (vio_out1)      // 11-bit
    );

    // -------------------------------------------------------------------------
    // 2. MASH111 + 小数分频
    // -------------------------------------------------------------------------
    wire signed [2:0] mash_carry;
    wire [7:0]        mash_e1;
    wire              div_out_raw;

    mash111 #(.WIDTH(8)) u_mash (
        .clk   (sys_clk_g),
        .rst_n (sys_rst_n),
        .frac  (frac),
        .carry (mash_carry),
        .e1    (mash_e1)
    );

    frac_div #(.INT_WIDTH(8)) u_div (
        .clk         (sys_clk_g),
        .rst_n       (sys_rst_n),
        .int_div     (int_div),
        .mash_carry  (mash_carry),
        .div_out     (div_out_raw)
    );

    // -------------------------------------------------------------------------
    // 3. DTC 补偿控制
    // -------------------------------------------------------------------------
    wire [8:0] dtc_code;
    wire       dtc_load;

    dtc_comp #(.WIDTH(8), .DTC_WIDTH(9)) u_dtc_ctrl (
        .clk             (sys_clk_g),
        .rst_n           (sys_rst_n),
        .e1              (mash_e1),
        .dtc_gain        (dtc_gain),
        .dtc_offset_sel  (dtc_offset_sel),
        .dtc_en          (dtc_en),
		.dtc_offset      (dtc_offset),
        .dtc_code        (dtc_code),
        .dtc_load        (dtc_load)
    );

    // -------------------------------------------------------------------------
    // 4. IDELAYE3 延迟线（补偿通道）
    // -------------------------------------------------------------------------
    wire div_out_dtc;
    wire idelay_rdy;

    (* IODELAY_GROUP = "DTC_GRP" *)
    IDELAYE3 #(
        .DELAY_TYPE       ("VAR_LOAD"),
        .DELAY_VALUE      (256),
        .REFCLK_FREQUENCY (300.0),
        .SIM_DEVICE       ("ULTRASCALE_PLUS"),
        .UPDATE_MODE      ("M_SYNC")
    ) u_idelaye3 (
        .C           (sys_clk_g),
        .IDATAIN     (div_out_raw),
        .DATAOUT     (div_out_dtc),
        .CE          (1'b0),
        .INC         (1'b0),
        .LD          (dtc_load),
        .CNTVALUEIN  (dtc_code),
        .CNTVALUEOUT (),
        .LDPIPEEN    (1'b0),
        .REGRST      (1'b0)
    );

    (* IODELAY_GROUP = "DTC_GRP" *)
    IDELAYCTRL u_idelayctrl (
        .REFCLK (clk_300m),
        .RST    (~sys_rst_n),
        .RDY    (idelay_rdy)
    );

    assign vio_in0 = idelay_rdy;

    // -------------------------------------------------------------------------
    // 5. ILA 观测
    // -------------------------------------------------------------------------
    ila_0 u_ila (
        .clk    (sys_clk_g),
        .probe0 (div_out_raw),
        .probe1 (div_out_dtc),
        .probe2 (mash_e1),
        .probe3 ({1'b0, mash_carry})  // 3-bit 扩展为 4-bit 匹配 ILA 宽度，或按实际 ILA 配置调整
    );

    // -------------------------------------------------------------------------
    // 6. SMA 差分输出（直接驱动顶层端口，无内部 assign）
    // -------------------------------------------------------------------------
    OBUFDS #(
        .IOSTANDARD("LVDS"),
        .SLEW("FAST")
    ) u_obuf_ref (
        .O  (sma_ref_p),
        .OB (sma_ref_n),
        .I  (div_out_raw)
    );

    OBUFDS #(
        .IOSTANDARD("LVDS"),
        .SLEW("FAST")
    ) u_obuf_dtc (
        .O  (sma_dtc_p),
        .OB (sma_dtc_n),
        .I  (div_out_dtc)
    );

endmodule
