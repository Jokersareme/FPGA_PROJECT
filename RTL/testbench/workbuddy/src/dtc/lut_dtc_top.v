`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/20 11:41:52
// Design Name: 
// Module Name: lut_dtc_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module lut_dtc_top #(
    parameter N_TAP = 512,
    parameter CODE_WIDTH = 9
) (
    input  wire              sys_clk,
    input  wire              rst_n,
    input  wire              din,
    input  wire [CODE_WIDTH-1:0] code,
    input  wire              cal_mode,
    input  wire [CODE_WIDTH-1:0] cal_code,
    input  wire              dtc_sel,
    input  wire              vco_clk,
    input  wire              idelay_en,       // 0=CARRY8链, 1=IDELAYE3
    input  wire              idelay_clk,      // IDELAYE3 时钟
    output wire              idelay_load,     // IDELAYE3 LOAD 脉冲
    output wire              dout,
    output wire  [CODE_WIDTH-1:0] cal_result,
    output wire               cal_valid
);

wire [4:0] div_out_dtc_i;
wire [19:0] cal_dtc_i;
wire [CODE_WIDTH-1:0] dtc_code;

assign div_out_dtc_i[0] = din;
// CARRY8 链输出
wire carry_dout;
assign carry_dout = (dtc_sel == 0) ? div_out_dtc_i[1] : div_out_dtc_i[4];
assign dtc_code = code;

// IDELAYE3 输出
wire idelay_dout;
assign idelay_load = 1'b1;  // 持续使能 LOAD (VAR_LOAD 模式)

// 输出选择
assign dout = idelay_en ? idelay_dout : carry_dout;

            (* DONT_TOUCH = "TRUE" *)
            lut_dtc #(
            .N_TAP (512),
            .CODE_WIDTH (9)
        ) u_lut_dtc_dly (
                     .sys_clk       (sys_clk),
                     .rst_n         (rst_n),
                     .din           (div_out_dtc_i[0]),
                     .code          (dtc_code),
                     .cal_mode      (1'b0),
                     .dtc_sel       (1'b0),
                     .dout          (div_out_dtc_i[1]),
                     .cal_result    (),
                     .cal_valid     ()
            );

            // 级 2~4 (3阶用, 4级链合计 ~8ns)
            (* DONT_TOUCH = "TRUE" *)
            lut_dtc #(.N_TAP(512), .CODE_WIDTH(9)) u_lut_dtc_dly2 (
                .sys_clk(sys_clk), .rst_n(rst_n),
                .din(div_out_dtc_i[1]), .code(dtc_code), .cal_mode(1'b0), .dtc_sel(1'b0),
                .dout(div_out_dtc_i[2]), .cal_result(), .cal_valid());

            (* DONT_TOUCH = "TRUE" *)
            lut_dtc #(.N_TAP(512), .CODE_WIDTH(9)) u_lut_dtc_dly3 (
                .sys_clk(sys_clk), .rst_n(rst_n),
                .din(div_out_dtc_i[2]), .code(dtc_code), .cal_mode(1'b0), .dtc_sel(1'b0),
                .dout(div_out_dtc_i[3]), .cal_result(), .cal_valid());

            (* DONT_TOUCH = "TRUE" *)
            lut_dtc #(.N_TAP(512), .CODE_WIDTH(9)) u_lut_dtc_dly4 (
                .sys_clk(sys_clk), .rst_n(rst_n),
                .din(div_out_dtc_i[3]), .code(dtc_code), .cal_mode(1'b0), .dtc_sel(1'b0),
                .dout(div_out_dtc_i[4]), .cal_result(), .cal_valid());

    // ============================================================
    // IDELAYE3 延迟路径 (替代 CARRY8 链)
    // idelay_en=1 时使用, 需要 IDELAYCTRL 提供参考时钟
    // ============================================================
    IDELAYE3 #(
        .CASCADE          ("NONE"),
        .DELAY_FORMAT     ("TIME"),
        .DELAY_SRC        ("DATAIN"),
        .DELAY_TYPE       ("VAR_LOAD"),
        .DELAY_VALUE      (0),
        .IS_CLK_INVERTED  (1'b0),
        .IS_RST_INVERTED  (1'b0),
        .REFCLK_FREQUENCY (300.0),
        .SIM_DEVICE       ("ULTRASCALE_PLUS"),
        .UPDATE_MODE      ("ASYNC")
    ) u_idelaye3 (
        .CLK         (idelay_clk),
        .CE          (1'b0),
        .CASC_IN     (1'b0),
        .CASC_RETURN (1'b0),
        .IDATAIN     (1'b0),
        .DATAIN      (din),
        .INC         (1'b0),
        .LOAD        (idelay_load),
        .CNTVALUEIN  ({{(9-CODE_WIDTH){1'b0}}, code}),
        .CNTVALUEOUT (),
        .DATAOUT     (idelay_dout),
        .CASC_OUT    (),
        .EN_VTC      (1'b1),
        .RST         (~rst_n)
    );

    genvar i;
    generate
        for (i = 1; i < 17; i = i + 1) begin : cascade
            lut_dtc_cal #(
                .CODE_WIDTH (9)
            ) u_lut_dtc_cal (
                .sys_clk    (sys_clk),
                .rst_n      (rst_n),
                .din        (cal_dtc_i[i-1]),
                .code       (cal_code),
                .dout       (cal_dtc_i[i]),
                .cal_result (),
                .cal_valid  ()
            );
        end
    endgenerate


// ============================================================
    // TDC 延迟测量模块 (vco_clk domain, 无 CDC 偏差)
    // 测量 din 上升沿到 16 级 lut_dtc 延迟链输出上升沿的 vco_clk 周期数
    //
    // CDC fix: cal_dtc_i[0] 不再直接接 din(sys_clk域),
    // 而是接 din_d2 (2级同步到 vco_clk 域后的输出).
    // 这样校准链的起止都在同一时钟域, 消除 0~2 vco_clk 的测量偏差.
    // ============================================================
    localparam TDC_WIDTH   = 9;
     
    reg din_d1, din_d2;                // din 同步寄存器 (vco_clk 域)
    reg [TDC_WIDTH-1:0] tdc_counter;   // 计数器
    reg [TDC_WIDTH-1:0] tdc_count;     // 锁存结果
    reg tdc_measuring;                  // 测量中标志
    reg tdc_valid;                      // 结果有效

    // cal_mode CDC: sys_clk → vco_clk 域 (2-flop synchronizer)
    reg cal_mode_m1, cal_mode_m2;
    
    // 校准链输入取自同步后的 din_d2 (即 vco_clk 域)
    assign cal_dtc_i[0] = din_d2;
    
    // 16 级 lut_dtc 延迟后的输出 (组合逻辑, 但传播需 ~122ns)
    wire din_delayed = cal_dtc_i[16];

    // 边沿检测 (vco_clk 域, 无跨时钟域问题)
    wire din_rise = din_d1 && !din_d2;

    always @(posedge vco_clk or negedge rst_n) begin
        if (!rst_n) begin
            din_d1 <= 1'b0;
            din_d2 <= 1'b0;
            tdc_counter <= {TDC_WIDTH{1'b0}};
            tdc_measuring <= 1'b0;
            tdc_count <= {TDC_WIDTH{1'b0}};
            tdc_valid <= 1'b0;
            cal_mode_m1 <= 1'b0;
            cal_mode_m2 <= 1'b0;
        end else begin
            // 将 din (sys_clk 域) 同步到 vco_clk 域
            din_d1 <= din;
            din_d2 <= din_d1;

            // cal_mode CDC: sys_clk → vco_clk
            cal_mode_m1 <= cal_mode;
            cal_mode_m2 <= cal_mode_m1;

            // 测量逻辑 (使用同步后的 cal_mode_vco)
            if (cal_mode_m2 && tdc_valid) begin
                // 保持上次校准结果不变
                tdc_valid <= tdc_valid;
                tdc_count <= tdc_count;
            
            end else if (cal_mode_m2) begin
                if (din_rise) begin
                    // din 上升沿: 开始计数 (从1开始, 因为本条边沿不算)
                    tdc_counter <= {{(TDC_WIDTH-1){1'b0}}, 1'b1};
                    tdc_measuring <= 1'b1;
                    tdc_valid <= 1'b0;
                end else if (tdc_measuring) begin
                    // 直接采样延迟链输出 (均在 vco_clk 域, 无 CDC)
                    if (din_delayed) begin
                        tdc_count <= tdc_counter;
                        tdc_valid <= 1'b1;
                        tdc_measuring <= 1'b0;
                    end else begin
                        tdc_counter <= tdc_counter + 1'b1;
                        tdc_valid <= 1'b0;
                    end
                end else begin
                    tdc_valid <= 1'b0;
                end
            end else begin
                // 非测量模式
                tdc_measuring <= 1'b0;
                tdc_counter <= {TDC_WIDTH{1'b0}};
                tdc_valid <= 1'b0;
            end
        end
    end

    assign cal_result = tdc_count;
    assign cal_valid  = tdc_valid;
    

endmodule

