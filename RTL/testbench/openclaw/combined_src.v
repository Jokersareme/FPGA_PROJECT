`timescale 1ns / 1ps
`timescale 1ns / 1ps
// CARRY8 行为模型 — 每级 5ps 延迟
// CO[tap] = S[tap] ? CO[tap-1] : DI[tap]
// 每级传播延迟 = 5ps
module CARRY8 #(parameter CARRY_TYPE="SINGLE_CY8")(
    output reg [7:0] CO, output [7:0] O,
    input [7:0] CI_TOP, input [7:0] DI, input [7:0] S, input CI);
    initial CO = 0;
    always @(*) begin
        CO[0] <= #0.020 (S[0]) ? CI      : DI[0];
        CO[1] <= #0.020 (S[1]) ? CO[0]   : DI[1];
        CO[2] <= #0.020 (S[2]) ? CO[1]   : DI[2];
        CO[3] <= #0.020 (S[3]) ? CO[2]   : DI[3];
        CO[4] <= #0.020 (S[4]) ? CO[3]   : DI[4];
        CO[5] <= #0.020 (S[5]) ? CO[4]   : DI[5];
        CO[6] <= #0.020 (S[6]) ? CO[5]   : DI[6];
        CO[7] <= #0.020 (S[7]) ? CO[6]   : DI[7];
    end
    assign O = 8'b0;
endmodule
﻿`timescale 1ns / 1ps
module IBUFDS #(parameter DIFF_TERM="FALSE", parameter IBUF_LOW_PWR="TRUE", parameter IOSTANDARD="DEFAULT") (output O, input I, input IB);
    assign #0.050 O = I;
endmodule
module OBUFDS #(parameter IOSTANDARD="DEFAULT", parameter SLEW="SLOW") (output O, output OB, input I);
    assign O = I; assign OB = ~I;
endmodule
module BUFG (output O, input I);
    assign #0.050 O = I;
endmodule
module BUFGMUX #(parameter CLK_SEL_TYPE="SYNC") (output O, input I0, input I1, input S);
    assign #0.050 O = S ? I1 : I0;
endmodule
// VIO stubs
module vio_0 (input clk, input [0:0] probe_in0, input [0:0] probe_in1, output [7:0] probe_out0, output [9:0] probe_out1, output [9:0] probe_out2, output [2:0] probe_out3, output [9:0] probe_out4, output [8:0] probe_out5, output [0:0] probe_out6);
    assign probe_out0 = 8'd100; assign probe_out1 = 10'd256; assign probe_out2 = 10'd160;
    assign probe_out3 = 3'd1; assign probe_out4 = 10'd12; assign probe_out5 = 9'd0; assign probe_out6 = 1'd0;
endmodule
// vio_cal moved to vio_override.v (order_sel=0 for 1st-order cal)
module vio_rst (input clk, output [0:0] probe_out0, output [0:0] probe_out1, output [0:0] probe_out2, output [0:0] probe_out3);
    reg rst_out = 0;
    assign probe_out0 = 1'b1; assign probe_out1 = 1'b1; assign probe_out3 = 1'b1;
    assign probe_out2 = rst_out;
    initial begin rst_out = 0; #20 rst_out = 1; end
endmodule
module vio_1 (input clk, output [0:0] probe_out0, output [9:0] probe_out1);
    // Manual dtc_code override for simulation (avoids X from uninit MASH)
    assign probe_out0 = 1'b0; assign probe_out1 = 10'd0;
endmodule
module vio_eo (input clk, output [1:0] probe_out0);
    // eo_dly_sel: 0=当前comp_3rd, 1=延迟1拍, 2=延迟2拍, 3=延迟3拍
    assign probe_out0 = 2'd1;
endmodule
module test_clk (input clk, output [2:0] probe_out0, output [2:0] probe_out1);
    assign probe_out0 = 3'd0; assign probe_out1 = 3'd0;
endmodule
module vio_ssc (input clk, output probe_out0, output [15:0] probe_out1);
    // spread_type=1 (down), spread_ppm=5000 (0.5%)
    assign probe_out0 = 1'b1;
    assign probe_out1 = 16'd5000;
endmodule
module ila_0 (input clk, input [0:0] probe0, input [0:0] probe1, input [9:0] probe2, input [2:0] probe3, input [8:0] probe4, input [8:0] probe5, input [0:0] probe6);
endmodule
module ila_1 (input clk, input [9:0] probe0, input [9:0] probe1, input [9:0] probe2, input [9:0] probe3, input [3:0] probe4);
endmodule
module ila_dualdiv (input clk, input [5:0] probe0, input [1:0] probe1, input [1:0] probe2, input [1:0] probe3, input [3:0] probe4, input [0:0] probe5);
endmodule
module mash_stage (input clk, output [1:0] probe_out0, output [1:0] probe_out1);
    assign probe_out0 = 2'd0; assign probe_out1 = 2'd0;
endmodule
module clk_wiz_0 (input clkfb_in, output clk_out1, output clkfb_out, input reset, output locked, input clk_in1);
    reg clk_out_r = 0; reg locked_r = 0; reg [15:0] lock_cnt = 0;
    always begin #1.2 clk_out_r = 1; #0.4 clk_out_r = 0; end
    always @(posedge clk_in1 or posedge reset) begin
        if (reset) begin lock_cnt <= 0; locked_r <= 0; end
        else if (!locked_r) begin if (lock_cnt < 16'd80) lock_cnt <= lock_cnt + 1; else locked_r <= 1; end
    end
    assign clk_out1 = clk_out_r; assign clkfb_out = clk_out_r; assign locked = locked_r;
endmodule

// IDELAYE3: Behavioral model for simulation
// Load code on LOAD posedge, delay DATAIN by code*10ps
module IDELAYE3 #(
    parameter CASCADE = "NONE",
    parameter DELAY_FORMAT = "TIME",
    parameter DELAY_SRC = "DATAIN",
    parameter DELAY_TYPE = "VAR_LOAD",
    parameter DELAY_VALUE = 0,
    parameter IS_CLK_INVERTED = 1'b0,
    parameter IS_RST_INVERTED = 1'b0,
    parameter REFCLK_FREQUENCY = 300.0,
    parameter SIM_DEVICE = "ULTRASCALE_PLUS",
    parameter UPDATE_MODE = "ASYNC"
)(
    input CLK, input CE, input CASC_IN, input CASC_RETURN,
    input IDATAIN, input DATAIN, input INC, input LOAD,
    input [8:0] CNTVALUEIN, output [8:0] CNTVALUEOUT,
    output DATAOUT, output CASC_OUT,
    input EN_VTC, input RST
);
    reg [8:0] delay_val = 0;
    reg dataout_r = 0;
    reg din_d = 0;
    
    // Capture delay value on LOAD posedge
    always @(posedge CLK or posedge RST) begin
        if (RST) delay_val <= 0;
        else if (LOAD) delay_val <= CNTVALUEIN;
    end
    
    // Apply delay: tap resolution ~10ps, max 512 taps = ~5.12ns
    // Use transport delay for sim
    always @(DATAIN or RST) begin
        if (RST) dataout_r <= 0;
        else dataout_r <= #(delay_val * 0.010) DATAIN;
    end
    
    assign DATAOUT = dataout_r;
    assign CNTVALUEOUT = delay_val;
    assign CASC_OUT = 1'b0;
endmodule

// IDELAYCTRL: Stub for simulation
module IDELAYCTRL #(parameter SIM_DEVICE = "ULTRASCALE")(
    input REFCLK, input RST, output RDY
);
    reg rdy_r = 0;
    reg [7:0] cnt = 0;
    always @(posedge REFCLK or posedge RST) begin
        if (RST) begin cnt <= 0; rdy_r <= 0; end
        else if (cnt < 100) begin cnt <= cnt + 1; rdy_r <= 0; end
        else rdy_r <= 1;
    end
    assign RDY = rdy_r;
endmodule


`timescale 1ns / 1ps
// 覆盖调整版：延长 cal_start 超时（40us→400us），保持 order_sel=1
module vio_cal (
    input               clk,
    output              probe_out0,     // cal_start
    output              probe_out1,     // cal_auto_en
    output              probe_out2,     // order_sel
    input      [9:0]    probe_in0,     // dtc_gain_cal
    input      [0:0]    probe_in1      // cal_done
);
    reg [19:0] cnt = 0;
    reg cal_start_r = 0;
    reg cal_start_done = 0;

    assign probe_out0 = cal_start_r;
    assign probe_out1 = 1'b0;           // cal_auto_en=0 (手动模式)
    assign probe_out2 = 1'b1;           // order_sel=1 (3阶)

    always @(posedge clk) begin
        if (cal_start_done) begin
            // 保持 cal_start=0
            cal_start_r <= 1'b0;
        end else if (cnt < 20'd125) begin         // ~1us @ 125MHz
            cnt <= cnt + 1;
            cal_start_r <= 1'b0;
        end else if (cnt == 20'd125) begin
            cal_start_r <= 1'b1;                   // 0→1 触发校准
            cnt <= cnt + 1;
        end else if (probe_in1) begin              // cal_done 后拉低
            cal_start_r <= 1'b0;
            cal_start_done <= 1'b1;
        end else if (cnt > 20'd50000) begin        // 超时 ~400us
            cal_start_r <= 1'b0;
            cal_start_done <= 1'b1;
        end else begin
            cnt <= cnt + 1;
        end
    end
endmodule
`timescale 1ns / 1ps
//
// Behavioral DTC delay model
// - Code-dependent delay: each stage adds code * 10ps
// - TDC: 16-stage cascade total = 16 * code * 10ps
//   At vco_clk=1.6ns: cal_result = (16 * code * 10ps) / 1600ps = code / 10
//
module lut_dtc #(
    parameter N_TAP       = 512,
    parameter CODE_WIDTH  = 9
)(
    input  wire                  sys_clk,
    input  wire                  rst_n,
    input  wire                  din,
    input  wire [CODE_WIDTH-1:0] code,
    input  wire                  cal_mode,
    input  wire                  dtc_sel,
    output wire                  dout,
    output reg  [CODE_WIDTH-1:0] cal_result,
    output reg                   cal_valid
);

    // ================================================================
    // 延时路径: code * 10ps / tap
    // ================================================================
    reg dout_r;

    always @(din or code) begin
        dout_r <= #(code * 0.010) din;
    end

    assign dout = dout_r;

    // ================================================================
    // TDC 模型 (per-lut_dtc, 用于校准链)
    // 16 级 cascade 总延迟 = 16 * code * 10ps
    // VCO ~625MHz (1.6ns) → cal_result = 16*code*10ps/1600ps = code/10
    // ================================================================
    reg [8:0] tdc_cnt  = 0;
    reg [8:0] tdc_code = 0;
    reg       tdc_busy = 0;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            cal_valid <= 1'b0;
            cal_result <= 0;
            tdc_cnt   <= 0;
            tdc_code  <= 0;
            tdc_busy  <= 0;
        end else if (cal_mode && !tdc_busy) begin
            tdc_code  <= code;
            tdc_cnt   <= code / 10;     // 16 stages * code * 10ps / 1600ps
            tdc_busy  <= 1;
            cal_valid <= 1'b0;
        end else if (tdc_busy) begin
            if (tdc_cnt == 0) begin
                tdc_busy  <= 0;
                cal_valid <= 1'b1;
                cal_result <= tdc_code / 10;
            end else begin
                tdc_cnt   <= tdc_cnt - 1;
                cal_valid <= 1'b0;
            end
        end else begin
            cal_valid <= 1'b0;
        end
    end

endmodule
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
    input  wire              idelay_en,       // 0=CARRY8?, 1=IDELAYE3
    input  wire              idelay_clk,      // IDELAYE3 ??
    output wire              idelay_load,     // IDELAYE3 LOAD ??
    output wire              dout,
    output wire  [CODE_WIDTH-1:0] cal_result,
    output wire               cal_valid
);

wire [4:0] div_out_dtc_i;
wire [19:0] cal_dtc_i;
wire [CODE_WIDTH-1:0] dtc_code;

assign div_out_dtc_i[0] = din;
// CARRY8 ???
wire carry_dout;
assign carry_dout = (dtc_sel == 0) ? div_out_dtc_i[1] : div_out_dtc_i[4];
assign dtc_code = code;

// IDELAYE3 ??
wire idelay_dout;
assign idelay_load = 1'b1;  // ???? LOAD (VAR_LOAD ??)

// ????
assign dout = carry_dout;

            
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

            // ? 2~4 (3??, 4???? ~8ns)
            
            lut_dtc #(.N_TAP(512), .CODE_WIDTH(9)) u_lut_dtc_dly2 (
                .sys_clk(sys_clk), .rst_n(rst_n),
                .din(div_out_dtc_i[1]), .code(dtc_code), .cal_mode(1'b0), .dtc_sel(1'b0),
                .dout(div_out_dtc_i[2]), .cal_result(), .cal_valid());

            
            lut_dtc #(.N_TAP(512), .CODE_WIDTH(9)) u_lut_dtc_dly3 (
                .sys_clk(sys_clk), .rst_n(rst_n),
                .din(div_out_dtc_i[2]), .code(dtc_code), .cal_mode(1'b0), .dtc_sel(1'b0),
                .dout(div_out_dtc_i[3]), .cal_result(), .cal_valid());

            
            lut_dtc #(.N_TAP(512), .CODE_WIDTH(9)) u_lut_dtc_dly4 (
                .sys_clk(sys_clk), .rst_n(rst_n),
                .din(div_out_dtc_i[3]), .code(dtc_code), .cal_mode(1'b0), .dtc_sel(1'b0),
                .dout(div_out_dtc_i[4]), .cal_result(), .cal_valid());

    // ============================================================
    // IDELAYE3 ???? (?? CARRY8 ?)
    // idelay_en=1 ???, ?? IDELAYCTRL ??????
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
            
            lut_dtc #(
            .N_TAP (512),
            .CODE_WIDTH (9)
        ) u_lut_dtc (
                     .sys_clk       (sys_clk),
                     .rst_n         (rst_n),
                     .din           (cal_dtc_i[i-1]),
                     .code          (cal_code),
                     .cal_mode      (1'b0),
                     .dtc_sel       (1'b0),
                     .dout          (cal_dtc_i[i]),
                     .cal_result    (),
                     .cal_valid     ()
            );
        end
    endgenerate


// ============================================================
    // TDC ?????? (vco_clk domain, ? CDC ??)
    // ?? din ???? 16 ? lut_dtc ????????? vco_clk ???
    //
    // CDC fix: cal_dtc_i[0] ????? din(sys_clk?),
    // ??? din_d2 (2???? vco_clk ?????).
    // ???????????????, ?? 0~2 vco_clk ?????.
    // ============================================================
    localparam TDC_WIDTH   = 9;
     
    reg din_d1, din_d2;                // din ????? (vco_clk ?)
    reg [TDC_WIDTH-1:0] tdc_counter;   // ???
    reg [TDC_WIDTH-1:0] tdc_count;     // ????
    reg tdc_measuring;                  // ?????
    reg tdc_valid;                      // ????

    // cal_mode CDC: sys_clk ? vco_clk ? (2-flop synchronizer)
    reg cal_mode_m1, cal_mode_m2;
    
    // ??????????? din_d2 (? vco_clk ?)
    assign cal_dtc_i[0] = din_d2;
    
    // 16 ? lut_dtc ?????? (????, ???? ~122ns)
    wire din_delayed = cal_dtc_i[16];

    // ???? (vco_clk ?, ???????)
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
            // ? din (sys_clk ?) ??? vco_clk ?
            din_d1 <= din;
            din_d2 <= din_d1;

            // cal_mode CDC: sys_clk ? vco_clk
            cal_mode_m1 <= cal_mode;
            cal_mode_m2 <= cal_mode_m1;

            // ???? (?????? cal_mode_vco)
            if (cal_mode_m2 && tdc_valid) begin
                // ??????????
                tdc_valid <= tdc_valid;
                tdc_count <= tdc_count;
            
            end else if (cal_mode_m2) begin
                if (din_rise) begin
                    // din ???: ???? (?1??, ????????)
                    tdc_counter <= {{(TDC_WIDTH-1){1'b0}}, 1'b1};
                    tdc_measuring <= 1'b1;
                    tdc_valid <= 1'b0;
                end else if (tdc_measuring) begin
                    // ????????? (?? vco_clk ?, ? CDC)
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
                // ?????
                tdc_measuring <= 1'b0;
                tdc_counter <= {TDC_WIDTH{1'b0}};
                tdc_valid <= 1'b0;
            end
        end
    end

    assign cal_result = tdc_count;
    assign cal_valid  = tdc_valid;
    

endmodule

`timescale 1ns / 1ps

// 输入位宽: WIDTH 可配; SHIFT 控制乘法结果右移量
// 限制: dtc_comp 的 SHIFT 必须与 dtc_calibrator 的 SHIFT 一致 (否则多 2^diff 因子)
// 目前两处都用 SHIFT=11 (SHIFT=12 时 K_BASE=32704, 10-bit gain 装不下)
// order_sel 仅控制 offset 自动居中: 1阶=0, 3阶=256
module dtc_comp #(
    parameter WIDTH = 13,
    parameter SHIFT = 11,       // 必须与 dtc_calibrator.SHIFT 一致
    parameter DTC_WIDTH = 9
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire [WIDTH-1:0]  e1,
    input  wire [9:0]        dtc_gain,
    input  wire              dtc_en,
    input  wire [DTC_WIDTH-1:0] dtc_offset,   // VIO 微调 offset (0~511)
    input  wire              order_sel,        // 0=1阶, 1=3阶(加256居中)
    output wire  [DTC_WIDTH-1:0] dtc_code,
    output wire               dtc_load         // 仅用于 ILA 观测, 无实际功能
);

    wire dtc_code_man_en;
    wire [9:0] dtc_code_man;

    // 3阶自动居中 offset (+256), 1阶不加
    // VIO 的 dtc_offset 作为微调
    wire [DTC_WIDTH-1:0] center_offset = order_sel ? (1 << (DTC_WIDTH-1)) : {DTC_WIDTH{1'b0}};

    // 乘法: e1 有符号, dtc_gain 无符号
    // 位宽: WIDTH+10 = 23-bit signed
    wire signed [WIDTH+9:0] mult = $signed({{10{e1[WIDTH-1]}}, e1}) * $signed({1'b0, dtc_gain});

    // 从 mult 中提取有效位
    // 问题: mult[SHIFT +: 10] (只取 10-bit) 在 3 阶误差较大时会溢出
    //   例如 e=4095, gain=1023: mult=4,189,185, mult[20:11]=2045 > 511
    //   10-bit signed 只能表示 -512~511, 2045 会截断为 -3 → code 算错
    // 修复: 提取 12-bit (DTC_WIDTH+3), 足以覆盖最大值 2045
    //   mult[22:11] = mult >> 11, 12-bit signed, 范围 -2048~2047, 安全
    wire signed [DTC_WIDTH+2:0] mult_ext = $signed(mult[SHIFT +: DTC_WIDTH+3]);

    // code_signed 用 13-bit (DTC_WIDTH+4) 防加法溢出
    //   max mult_ext=2045, + center_offset=256, + dtc_offset=511 → 2812 < 4095 ✓
    wire signed [DTC_WIDTH+3:0] code_signed = $signed(mult_ext)
                                            + $signed({{4{1'b0}}, center_offset})
                                            + $signed({{4{1'b0}}, dtc_offset});

    // 饱和到 0~511, 使用 10'sd511 避免 9'sd511=-1 的 bug
    wire [DTC_WIDTH-1:0] code_sat = (code_signed > 10'sd511) ? {DTC_WIDTH{1'b1}} :
                                     (code_signed < 0)       ? {DTC_WIDTH{1'b0}} :
                                     code_signed[DTC_WIDTH-1:0];
    
    
    // dtc_code 组合输出, 经 dtc_code_pipe/Fout 域寄存器后再进 CARRY8
    assign dtc_code = dtc_en ? (dtc_code_man_en ? dtc_code_man[DTC_WIDTH-1:0] : code_sat) : {DTC_WIDTH{1'b0}};

    // dtc_load: 仅用于 ILA 观测 (IDELAYE3 已取消), 始终为 1
    assign dtc_load = dtc_en;

    vio_1 u_vio_dtc_comp (
  .clk(clk),                // input wire clk
  .probe_out0(dtc_code_man_en),  // output wire [0 : 0] probe_out0
  .probe_out1(dtc_code_man)  // output wire [8 : 0] probe_out1
);


endmodule
`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: dtc_calibrator
//
// ???? (??????1?, ??2?):
//   1. cal_mode_ext ? ??
//   2. dtc_code=0, cal_mode=1 ? ? cal_valid (?1????)
//   3. cal_mode=0?1 (??TDC) ? ? cal_valid (?2??? tdc_min)
//   4. dtc_code=511, ?????? ? ? tdc_max
//   5. dtc_gain = K / (tdc_max - tdc_min)
//   K = (2^SHIFT ? 16 ? MAX_CODE / 2^FRAC_WIDTH) / N_STAGES
//     order_sel=0: N_STAGES=1, 1??, K = K_BASE
//     order_sel=1: N_STAGES=4, 4??, K = K_BASE / 4
////////////////////////////////////////////////////////////////////////////////

module dtc_calibrator #(
    parameter FRAC_WIDTH = 10,
    parameter CODE_WIDTH = 9,
    parameter GAIN_WIDTH = 10,
    parameter TDC_WIDTH  = 9,
    parameter MAX_CODE   = 511,
    parameter SHIFT      = 11
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                cal_mode_ext,
    input  wire                order_sel,      // 0=1?(K=K_BASE), 1=3?(K=K_BASE/4)
    output reg                 cal_mode,
    input  wire [TDC_WIDTH-1:0] cal_result,
    input  wire                cal_valid,
    output reg [CODE_WIDTH-1:0] dtc_code_cal,
    output reg [GAIN_WIDTH-1:0] dtc_gain_cal,
    output reg                 cal_done,
    output reg [TDC_WIDTH-1:0] tdc_min,
    output reg [TDC_WIDTH-1:0] tdc_max
);

    localparam K_BASE = ((1 << SHIFT) * 16 * MAX_CODE) >> FRAC_WIDTH;  // 15-bit max
    wire [14:0] K_CONST = K_BASE;

    localparam [3:0]
        S_IDLE        = 4'd0,
        SM_MIN_CODE   = 4'd1,
        SM_MIN_DISCARD= 4'd2,
        SM_MIN_FLUSH  = 4'd3,
        SM_MIN_MEAS   = 4'd4,
        SM_MIN_STORE  = 4'd5,
        SM_MAX_CODE   = 4'd6,
        SM_MAX_DISCARD= 4'd7,
        SM_MAX_FLUSH  = 4'd8,
        SM_MAX_MEAS   = 4'd9,
        SM_MAX_STORE  = 4'd10,
        SM_DIVIDE     = 4'd11,
        SM_SATURATE   = 4'd12,
        SM_DONE       = 4'd13;

    reg [3:0] state, next;
    reg ce_d1;
    wire ce_rise;
    reg [15:0] wait_cnt;

    // ??? (15-bit ? 10-bit = 10-bit)
    reg [14:0] dividend;
    reg [9:0]  divisor;
    reg [14:0] quotient;   // 15-bit 商（15 次迭代）
    reg [14:0] remainder;
    reg [3:0]  div_cnt;
    reg        div_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ce_d1 <= 1'b0;
        else        ce_d1 <= cal_mode_ext;
    end
      // ce_rise moved to always @(*):

    // ====================================================================
    // ????
    // ====================================================================
    always @(*) begin
        next = state;
        // cal_mode_ext=0 ???���´?״̬???? (�κ�ʱ����ֹУ׼)
        if (state != S_IDLE && !cal_mode_ext) begin
            next = S_IDLE;
        end else begin
        case (state)
            S_IDLE:         if (cal_mode_ext && !ce_d1) next = SM_MIN_CODE;
            SM_MIN_CODE:    next = SM_MIN_DISCARD;
            SM_MIN_DISCARD: if (cal_valid || wait_cnt == 16'hFFFF) next = SM_MIN_FLUSH;
            SM_MIN_FLUSH:   next = SM_MIN_MEAS;
            SM_MIN_MEAS:    if (cal_valid || wait_cnt == 16'hFFFF) next = SM_MIN_STORE;
            SM_MIN_STORE:   next = SM_MAX_CODE;
            SM_MAX_CODE:    next = SM_MAX_DISCARD;
            SM_MAX_DISCARD: if (cal_valid || wait_cnt == 16'hFFFF) next = SM_MAX_FLUSH;
            SM_MAX_FLUSH:   next = SM_MAX_MEAS;
            SM_MAX_MEAS:    if (cal_valid || wait_cnt == 16'hFFFF) next = SM_MAX_STORE;
            SM_MAX_STORE:
                if (tdc_max > tdc_min) next = SM_DIVIDE;
                else                   next = SM_SATURATE;
            // ??: action ? case(next) ??
            // ? div_cnt>=10 ??? next=SM_DONE, finish ??????
            // ????: div_cnt=10 ? ? SM_DIVIDE ??? finish ? div_busy=0 ? ???? SM_DONE
            SM_DIVIDE:      if (div_busy && div_cnt >= 4'd10) next = SM_DIVIDE;  // ???? finish
                            else if (!div_busy)               next = SM_DONE;    // finish ???, ?
                            else                              next = SM_DIVIDE;
            SM_SATURATE:    next = SM_DONE;
            SM_DONE:        next = S_IDLE;
        endcase
        end
    end

    // ====================================================================
    // ????
    // ====================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; cal_mode <= 1'b0; dtc_code_cal <= 0;
            tdc_min <= 0; tdc_max <= 0; dtc_gain_cal <= 0;
            cal_done <= 1'b0; wait_cnt <= 0;
            dividend <= 0; divisor <= 0; quotient <= 0;
            remainder <= 0; div_cnt <= 0; div_busy <= 1'b0;
        end else begin
            state <= next;
            cal_done <= 1'b0;

            case (next)
                S_IDLE: begin
                    cal_mode <= 1'b0; wait_cnt <= 0; div_busy <= 1'b0;
                end

                SM_MIN_CODE: begin
                    cal_mode <= 1'b1; dtc_code_cal <= 0; wait_cnt <= 0;
                end
                SM_MIN_DISCARD: wait_cnt <= wait_cnt + 1;
                SM_MIN_FLUSH: begin
                    cal_mode <= 1'b0; wait_cnt <= 0;
                end
                SM_MIN_MEAS: begin
                    cal_mode <= 1'b1; wait_cnt <= wait_cnt + 1'b1;
                end
                SM_MIN_STORE: begin
                    tdc_min <= cal_result; cal_mode <= 1'b0; wait_cnt <= 0;
                end

                SM_MAX_CODE: begin
                    cal_mode <= 1'b1; dtc_code_cal <= MAX_CODE[CODE_WIDTH-1:0]; wait_cnt <= 0;
                end
                SM_MAX_DISCARD: wait_cnt <= wait_cnt + 1;
                SM_MAX_FLUSH: begin
                    cal_mode <= 1'b0; wait_cnt <= 0;
                end
                SM_MAX_MEAS: begin
                    cal_mode <= 1'b1; wait_cnt <= wait_cnt + 1'b1;
                end
                SM_MAX_STORE: begin
                    tdc_max <= cal_result; cal_mode <= 1'b0; wait_cnt <= 0;
                end

                SM_DIVIDE: begin
                    if (!div_busy) begin
                        dividend  <= K_CONST;
                        divisor   <= {1'b0, tdc_max - tdc_min};  // 10-bit
                        quotient  <= 0; remainder <= 0;
                        div_cnt   <= 0; div_busy <= 1'b1;
                    end else if (div_cnt < 4'd15) begin   // 15 次迭代
                        // 用 15-bit 完整移位后余数比较和减法
                        if ({remainder[13:0], dividend[14]} >= {5'b0, divisor}) begin
                            quotient[14 - div_cnt] <= 1'b1;
                            remainder <= {remainder[13:0], dividend[14]} - {5'b0, divisor};
                        end else begin
                            quotient[14 - div_cnt] <= 1'b0;
                            remainder <= {remainder[13:0], dividend[14]};
                        end
                        dividend <= {dividend[13:0], 1'b0};
                        div_cnt  <= div_cnt + 1'b1;
                    end else begin
                        div_busy <= 1'b0;
                        // 15-bit 商截低 10 bit 给 gain
                        dtc_gain_cal <= (quotient[9:0] > 10'd1023) ? 10'd1023 : quotient[9:0];
                    end
                end

                SM_SATURATE: dtc_gain_cal <= {GAIN_WIDTH{1'b1}};
                SM_DONE:     cal_done <= 1'b1;
            endcase
        end
    end

endmodule
`timescale  1ns / 1ps

module dff (
    input clk,
    input LD,
    input rst_n,
    input P,
    input D,
    output reg Q = 0,
    output Qn
);
	
    always @(posedge clk or negedge rst_n or posedge LD) begin
		if (~rst_n) begin
			Q <= 1'b0;
		end else if (LD) begin
            Q <= P;
        end else begin
            Q <= D;
        end
    end
    
    assign Qn = ~Q;
    
endmodule`timescale  1ns / 1ps

module reg_async #(
    parameter WIDTH = 1
) (
    input clk,
    // input rst_n,

    input [WIDTH-1:0] D,
    output reg [WIDTH-1:0] Q,
    output [WIDTH-1:0] Qn
);

    always @(posedge clk) begin
        Q <= Q;
    end
    
    assign Qn = ~Q;
    
endmodule`timescale  1ns / 1ps

module reg_sync #(
    parameter WIDTH = 1,
    parameter RST_VALUE = 0
) (
    input clk,
    input rst_n,

    input [WIDTH-1:0] D,
    output reg [WIDTH-1:0] Q=0,
    output [WIDTH-1:0] Qn
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Q <= {WIDTH{RST_VALUE}};
        end else begin
            Q <= D;
        end
    end
    
    assign Qn = ~Q;
    
endmodule`timescale  1ns / 1ps

module div2 (
    input clk,
    input rst_n,

    output fout
);

// reg_sync Parametersnc.v
parameter WIDTH      = 1;
parameter RST_VALUE  = 0;

// // reg_sync Inputs
// reg   clk;
// reg   rst_n;
wire  [WIDTH-1:0]  D;

// reg_sync Outputs
wire  [WIDTH-1:0]  Q;
wire  [WIDTH-1:0]  Qn;

assign D = Q;
assign fout = Q;

reg_sync #(
    .WIDTH     ( WIDTH ),
    .RST_VALUE ( RST_VALUE ))
 u_reg_sync (
    .clk                     ( clk     ),
    .rst_n                   ( rst_n   ),
    .D                       ( D       ),

    .Q                       ( Q       ),
    .Qn                      ( Qn      )
);
    
endmodule`timescale 1ns / 1ps

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
`timescale  1ns / 1ps

module div_89 (
    input clk,
    input rst_n,
    input MC,    // MC = 0 时，8分频；MC = 1 时，9分频

    output f45,
    output f89
);

    wire D1;
    wire Q1;
    wire Qn1;
    wire D2;
    wire Q2;
    wire Qn2;
    wire D3;
    wire Q3;
    wire Qn3;
    wire D4;
    wire Q4;
    wire Qn4;

    // 这部分原理见 8/9 分频器的结构图
    assign D1 = ~(Q2 & Q3);
    assign D2 = Q1;
    assign D3 = ~(Qn2 & (Qn4 & MC));
    assign D4 = Qn4;

    assign f89 = Qn4; // 异步 8/9 分频
    assign f45 = Qn1; // 同步 4/5 分频

    // D 触发器
    reg_sync #(
        .WIDTH ( 1 ))
    u1_reg_sync (
        .clk                     ( clk   ),
        .rst_n                   ( rst_n ),
        .D                       ( D1    ),
        .Q                       ( Q1    ),
        .Qn                      ( Qn1   )
    );

    reg_sync #(
        .WIDTH ( 1 ))
    u2_reg_sync (
        .clk                     ( clk   ),
        .rst_n                   ( rst_n ),
        .D                       ( D2    ),
        .Q                       ( Q2    ),
        .Qn                      ( Qn2   )
    );

    reg_sync #(
        .WIDTH ( 1 ))
    u3_reg_sync (
        .clk                     ( clk   ),
        .rst_n                   ( rst_n ),
        .D                       ( D3    ),
        .Q                       ( Q3    ),
        .Qn                      ( Qn3   )
    );

    reg_sync #(
        .WIDTH ( 1 ))
    u4_reg_sync (
        .clk                     ( Q1    ),
        .rst_n                   ( rst_n ),
        .D                       ( D4    ),
        .Q                       ( Q4    ),
        .Qn                      ( Qn4   )
    );
    
endmodule`timescale  1ns / 1ps

// P/S 双模分频器
// 修复: 删除 ss_cnt/MC_dly 延迟链，MC 直接连接
// 原 MC_dly 用自由计数器延迟 MC 信号，导致 4/5 预分频器模数切换错位 → 输出周期突变(毛刺)
// MC 来自 s_counter 的 mc_q，已在 Fin 上寄存并通过 LDi 与分频周期边界同步，无需额外延迟
module dual_div #(
    parameter P_WIDTH = 6,
    parameter S_WIDTH = 2
) (
    input wire clk,              // 时钟输入 (Fin, 625MHz)
    input wire clk_ila,          // ILA 时钟
    input wire rst_n,            // 复位信号，低有效
    input wire [S_WIDTH-1:0] Si, // S 计数器的最大值
    input wire [P_WIDTH-1:0] Pi, // P 计数器的最大值

    output wire Fdiv             // 分频输出
);

    wire  f45;
    wire  MC;
    wire  LD;

    ila_dualdiv u_ila_dualdiv (
        .clk(clk_ila),

        .probe0(Pi),            // input wire [5:0]  probe0
        .probe1(Si),            // input wire [1:0]  probe1
        .probe2({f45,Fdiv}),    // input wire [1:0]  probe2
        .probe3({MC,MC}),       // input wire [1:0]  probe3  (原为{MC,MC_dly}，现两者均为MC)
        .probe4(4'd0),          // input wire [3:0]  probe4  (原为ss_cnt，已删除)
        .probe5(LD)             // input wire [0:0]  probe5
    );

    div_45  u_div_45 (
        .clk                     ( clk        ),
        .rst_n                   ( rst_n      ),
        .MC                      ( MC         ),  // 修复: 原为 MC_dly，现直接用 MC

        .f45                     ( f45        )
    );

    p_counter #(
        .WIDTH ( P_WIDTH ))
    u_p_counter (
        .rst_n                   ( rst_n   ),
        .Fin                     ( f45     ),
        .Pi                      ( Pi      ),

        .Fout                    ( Fdiv    ),
        .LDo                     ( LD      )
    );

    s_counter #(
        .WIDTH ( S_WIDTH ))
    u_s_counter (
		.rst_n                   ( rst_n ),
        .Fin                     ( f45   ),
        .Si                      ( Si    ),
        .LDi                     ( LD    ),

        .MCo                     ( MC    )
    );

endmodule
`timescale  1ns / 1ps

module efm #(
    parameter WIDTH = 24
) (
    input clk,
    input rst_n,

    input [WIDTH-1:0] x_i,
    output y_o,
    output [WIDTH-1:0] e_o
);

    wire [WIDTH:0] sum;
    reg [WIDTH-1:0] error_r;

    assign sum = x_i + error_r;

    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         sum_r <= 'b0;
    //     end else begin
    //         sum_r <= x_i + error_r; 
    //     end
    // end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_r <= 'b0;
        end else begin
            error_r <= sum[WIDTH-1:0];
        end
    end

    // 原始输出
    assign e_o = sum[WIDTH-1:0];
    assign y_o = sum[WIDTH];
    // // 优化输出
    // reg [WIDTH:0] sum_r;
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         sum_r <= 'b0;
    //     end else begin
    //         sum_r <= sum; 
    //     end
    // end
    // assign e_o = sum_r[WIDTH-1:0];
    // assign y_o = sum_r[WIDTH];

endmodule`timescale  1ns / 1ps

module hk_efm #(
    parameter WIDTH = 24,  // ???????
    parameter A_GAIN = 1   // A = A_GAIN*2-1, ?????????????????
) (
    input clk,             // ????
    input rst_n,           // ????????

    input [WIDTH-1:0] x_i, // ???????????EFM????
    output y_o,            // ????
    output [WIDTH-1:0] e_o // ?????????? EFM ???
);

    wire [WIDTH:0] sum;
    reg [WIDTH:0] sum_r = 0;

    // ?????????????????????????
    assign sum = x_i + sum_r[WIDTH-1:0] - {A_GAIN{sum_r[WIDTH]}};
    // assign sum = x_i + sum_r[WIDTH-1:0];

    // ?????????????
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_r <= 'b0;
        end else begin
            sum_r <= sum;
        end
    end

    // ????
    assign e_o = sum_r[WIDTH-1:0];
    // assign y_o = sum[WIDTH];
    // ????
    // ??? y ????????????? Sigma-Delta ??????????? Sigma-Delta ??????? y ??????????????????????????????
    assign y_o = sum_r[WIDTH];

endmodule`timescale  1ns / 1ps

module mash111 #(
    parameter WIDTH = 24,  // ???????
    parameter A_GAIN = 1   // A = A_GAIN*2-1, ?????????????????
) (
    input clk,             // ????
    input clk_ila,             // ????
    input rst_n,           // ????????

    input [WIDTH-1:0] x_i, // Sigma-Delta ????????????????
    output reg [3:0] y_o,      // ????
    output [WIDTH-1:0] e_o, // ???? EFM ?????
    output [WIDTH-1:0] e1_o, // ?1? EFM ???? (?? 3 ? DTC ??)
    output [WIDTH-1:0] e2_o, // ?2? EFM ????
    output [WIDTH-1:0] e3_o  // ?3? EFM ????
);

    wire [WIDTH-1:0] x_i_1;
    wire [WIDTH-1:0] e_o_1;
    wire y_o_1;
    wire [WIDTH-1:0] x_i_2;
    wire [WIDTH-1:0] e_o_2;
    wire y_o_2;
    wire [WIDTH-1:0] x_i_3;
    wire [WIDTH-1:0] e_o_3;
    wire y_o_3;
    
    
    reg y2_d = 0;
    reg y3_d = 0;
    reg y3_dd = 0;

    wire signed [2:0] c1;
    wire signed [3:0] c2;
    reg signed [0:0] c0_reg = 0;
    reg signed [2:0] c1_reg = 0; 

    wire [1:0] stage_sel;
    wire  mash_eo_mode;
    reg [WIDTH-1:0] eo_d1 = 0;

        
    // ??? efm ?????????? efm ???
    assign x_i_1 = x_i;
    assign x_i_2 = e_o_1;
    assign x_i_3 = e_o_2;

    // ? 3 ? efm ?????
    assign c1 = y_o_2 + y_o_3 - c0_reg;
    assign c2 = y_o_1 + {c1[2], c1} - {c1_reg[2], c1_reg}; // ?????

//    assign y_o = c2;

    // ???? EFM ??????? combiner
    assign e1_o = e_o_1;
    assign e2_o = e_o_2;
    assign e3_o = e_o_3;
    // ??????, ?? e_o (?? e1 ? 1 ???)
    assign e_o = eo_d1;

    // ??
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c0_reg <= 'b0;
            c1_reg <= 'b0;
            y2_d  <= 1'b0;
            y3_d  <= 1'b0;
            y3_dd <= 1'b0;
        end else begin
            c0_reg <= y_o_3;
            c1_reg <= c1;
            y2_d <= y_o_2;
            y3_d <= y_o_3;
            y3_dd <= y3_d;
        end 
    end
    
        always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eo_d1 <= 1'b0;
			y_o <= 4'b0;
        end else begin
            eo_d1 <= e_o_1;
			y_o <=  (stage_sel == 2'b00) ? c2 :
					(stage_sel == 2'b01) ? y_o_1 :
					(stage_sel == 2'b10) ? y_o_1 + y_o_2 - y2_d : y_o_1 + y_o_2 - y2_d + (y_o_3 - y3_d - y3_d + y3_dd);
        end 
		end


    // ?? efm ??
    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_1 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_1   ),

        .y_o                     ( y_o_1   ),
        .e_o                     ( e_o_1   )
    );

    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_2 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_2   ),

        .y_o                     ( y_o_2   ),
        .e_o                     ( e_o_2   )
    );

    hk_efm #(
        .WIDTH ( WIDTH ),
        .A_GAIN(A_GAIN))
    u_hk_efm_3 (
        .clk                     ( clk     ),
        .rst_n                   ( rst_n   ),
        .x_i                     ( x_i_3   ),

        .y_o                     ( y_o_3   ),
        .e_o                     ( e_o_3   )
    );
//    assign stage_sel = 2'b01;
    mash_stage u_mash_stage (
        .clk (clk),
        .probe_out0 (stage_sel),
        .probe_out1 (mash_eo_mode)
    );
    
        ila_1 u_ila (
        .clk    (clk_ila),
        .probe0 (x_i_1),
        .probe1 (e_o_1),
        .probe2 (e_o_2),
        .probe3 (e_o_3),  // 3-bit ??? 4-bit ?? ILA ??????? ILA ????
        .probe4 (y_o)  // 3-bit ??? 4-bit ?? ILA ??????? ILA ????
    );
    
endmodule`timescale  1ns / 1ps

// 修复: Fout 由组合逻辑改为寄存器输出，消除 Pi 变化时的组合毛刺
// 原设计: assign Fout = (qn_o == ~Pi_correct | qn_o == ~(Pi_correct-1)) ? 1 : 0;
// 问题: Pi 来自 calculate_ps (~Fout_reg 下降沿更新)，更新时 p_counter 可能正在计数
//       新的 Pi_correct 可能与当前 qn_o 瞬间匹配，在 Fout 上产生窄脉冲
//       Fout_raw → Fout_reg(posedge Fin=625MHz) 会捕获该毛刺
// 修复: Fout 在 Fin(=f45) 上寄存一拍，增加 1 个 f45 周期延迟，对反馈环路影响可忽略
module p_counter #(
    parameter WIDTH = 5
) (
    input wire rst_n,
    input wire Fin,
    input wire [WIDTH-1:0] Pi,

    output wire  Fout,            // 修复: 改为寄存器输出
    output wire LDo
);

    wire [WIDTH-1:0] clk_i;
    wire [WIDTH-1:0] d_i;
    wire [WIDTH-1:0] q_o;
    wire [WIDTH-1:0] qn_o;
    wire [WIDTH-1:0] LD_i;

    wire h_nand;
    wire ld_d;
    wire ld_q;
    wire [WIDTH-1:0] Pi_correct;
    reg rst_n_d1;
    wire ldi;

    // Generate block
    genvar i;
    generate
        for(i=0; i<WIDTH; i=i+1) begin:BLOCK1
            dff  u_dff (
                .clk                     ( clk_i[i]   ),
                .LD                      ( LD_i[i]    ),
				.rst_n					 ( rst_n	  ),
                .P                       ( Pi_correct[i]      ),
                .D                       ( d_i[i]     ),

                .Q                       ( q_o[i]     ),
                .Qn                      ( qn_o[i]    )
            );
        end
    endgenerate

    dff  u_ld_dff (
        .clk                     ( Fin      ),
        .LD                      ( ~rst_n   ),
		.rst_n					 ( rst_n	),
        .P                       ( 1'b1     ),
        .D                       ( ld_d     ),

        .Q                       ( ld_q     ),
        .Qn                      (          )
    );

    always @(posedge Fin) begin
        rst_n_d1 <= rst_n;
    end

    assign ldi = (rst_n == 1 & rst_n_d1 == 0) ? 1 : 0;
	assign Fout = ld_q; //qn_o[Pi_correct] & qn_o[Pi_correct-1];
    assign Pi_correct = Pi - 1'd1;
    assign d_i = qn_o;
    assign clk_i[0] = Fin;
    assign clk_i[WIDTH-1:1] = q_o[WIDTH-2:0];
    assign h_nand = ~(&qn_o[WIDTH-1:1]);
    assign ld_d = ~(qn_o[0]|h_nand);
    assign LD_i = {WIDTH{ld_q}};
    assign LDo = ld_q;

    // ============================================================
    // 修复: Fout 寄存一拍，消除 Pi 变化时的组合毛刺
    // ============================================================
    //always @(posedge Fin or negedge rst_n) begin
    //    if (!rst_n)
    //        Fout <= 1'b0;
    //    else
    //        Fout <= qn_o[Pi_correct] & qn_o[Pi_correct] ;
    //end

endmodule
`timescale  1ns / 1ps

// 修复: 门控时钟 clk_i[0] = ~((~h_and)&(~Fin)) 改为时钟使能方式
// 问题: 组合逻辑生成的门控时钟在 h_and/Fin 变化时会产生毛刺，导致 DFF 误触发
// 修复: clk_i[0] 直接使用 Fin，在 D 输入端加使能逻辑
//       使能 = ~h_and，即计数器未全1时允许翻转，全1时保持
module s_counter #(
    parameter WIDTH = 3
) (
    input rst_n,
    input wire Fin,
    input wire [WIDTH-1:0] Si,
    input wire LDi,

    output wire MCo
);

    wire [WIDTH-1:0] clk_i;
    wire [WIDTH-1:0] d_i;
    wire [WIDTH-1:0] q_o;
    wire [WIDTH-1:0] qn_o;
    wire [WIDTH-1:0] LD_i;

    wire h_and;
    wire mc_d;
    wire mc_q;
    reg rst_n_d1;
    wire ldi;

    genvar i;
    generate
        for(i=0; i<WIDTH; i=i+1) begin:BLOCK1
            dff  u_dff (
                .clk                     ( clk_i[i]   ),
                .LD                      ( LD_i[i]    ),
				.rst_n					 ( rst_n	  ),
                .P                       ( Si[i]      ),
                .D                       ( d_i[i]     ),

                .Q                       ( q_o[i]     ),
                .Qn                      ( qn_o[i]    )
            );
        end
    endgenerate

    dff  u_mc_dff (
        .clk                     ( Fin      ),
        .LD                      ( ~rst_n     ),
		.rst_n			 		 ( rst_n	  ),
        .P                       ( 1'b1     ),
        .D                       ( mc_d     ),

        .Q                       ( mc_q     ),
        .Qn                      (     )
    );

    always @(posedge Fin) begin
        rst_n_d1 <= rst_n;
    end

    assign ldi = (rst_n == 1 & rst_n_d1 == 0) ? 1 : 0;

    // ============================================================
    // 修复: 门控时钟改时钟使能
    // 原: assign clk_i[0] = ~((~h_and)&(~Fin));  -- 门控时钟，有毛刺风险
    // 改为: clk_i[0]=Fin (纯时钟), d_i[0] 在 h_and=1 时保持原值
    // ============================================================
    assign h_and = &qn_o;

    // 修复: bit0 使用 Fin 作为时钟，通过 d_i 实现使能
    assign clk_i[0] = Fin;                           // 纯时钟，无门控
    assign d_i[0]   = h_and ? q_o[0] : qn_o[0];     // 使能逻辑: h_and=1时保持
    assign d_i[WIDTH-1:1] = qn_o[WIDTH-1:1];        // 高位不变

    assign clk_i[WIDTH-1:1] = q_o[WIDTH-2:0];
    assign mc_d = ~(LDi|h_and);
    assign MCo = mc_q;
    assign LD_i = {WIDTH{LDi}};

endmodule
`timescale  1ns / 1ps

// ????????? Sigma-Delta ????????????????????? P ???? S ???
module calculate_ps #(
    parameter P_WIDTH = 6,
    parameter S_WIDTH = 2,
    parameter INT_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,

    input wire [INT_WIDTH-1:0] Integer,  // ????

    input wire [3:0] delta_sigma,        // Sigma-Delta ??????

    input wire [9:0] Ei,        // Sigma-Delta ??????
	
    output wire [S_WIDTH-1:0] Si,
    output wire [P_WIDTH-1:0] Pi,
	
    output reg [9:0] Eo        // Sigma-Delta ??????
);

    reg [INT_WIDTH-1:0] real_integer = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            real_integer <= Integer;
			Eo <= 0;
        end else begin
            real_integer <= Integer + {{(INT_WIDTH-4){delta_sigma[3]}}, delta_sigma};
//            real_integer <= Integer + {{(INT_WIDTH-4){delta_sigma[3]}}, delta_sigma};
			Eo <= Ei;
        end
    end

    //assign Pi = real_integer[INT_WIDTH-1:INT_WIDTH-P_WIDTH];
	assign Pi = real_integer >> 2;
    assign Si = real_integer[S_WIDTH-1:0];
    
endmodule`timescale  1ns / 1ps

// ??????????????? mash111-Sigma-Delta ?????????
module fractionaln #(
    parameter P_WIDTH = 6,                  // P ??????
    parameter S_WIDTH = 2,                  // S ??????
    parameter INT_WIDTH = 8,                // ???????
    parameter FRAC_WIDTH = 10               // ???????
) (
    input wire Fin,                         // ????????
    input wire Sys_clk,                         // ????????
    input wire rst_n,                       // ????????

    input wire [INT_WIDTH-1:0] Integer,     // ??????
    input wire [FRAC_WIDTH-1:0] Fraction,   // ??????
    
    output reg [FRAC_WIDTH-1:0] Eo,          // 1 ??? (???)
    output reg [FRAC_WIDTH+2:0] E_combined,  // 3 ????? (?? 3 ? DTC ??)
    output wire Fout                         // ????
);

	wire rst_n_sync;
    wire [3:0] delta_sigma;
    wire clk_delta_sigma;
    wire [S_WIDTH-1:0] Si;
    wire [P_WIDTH-1:0] Pi;
    //reg Fout_reg;
    wire [FRAC_WIDTH-1:0] Eo_raw;
    wire [FRAC_WIDTH-1:0] mash_e1, mash_e2, mash_e3;  // ?? EFM ????
	reg [FRAC_WIDTH-1:0] Eo_d1 = 0;
	reg [FRAC_WIDTH-1:0] Eo_d2 = 0;
	reg [FRAC_WIDTH-1:0] Eo_d3 = 0;

    // 3 ? combiner: e? + (e? - e?[n-1]) + (e? - 2?e?[n-1] + e?[n-2])
    // ??: Eo_raw (= e1[n-1]) ?? 1 ???,
    //       mash_e2/mash_e3 ?????, ??? 1 ???? e1
    reg [FRAC_WIDTH-1:0] e1_r = 0;                           // = e1[n-1]
    reg [FRAC_WIDTH-1:0] e2_r1 = 0, e2_r2 = 0, e2_r3 = 0;           // e2[n], e2[n-1], e2[n-2]
    reg [FRAC_WIDTH-1:0] e3_r1 = 0, e3_r2 = 0, e3_r3 = 0, e3_r4 = 0;     // e3[n], e3[n-1], e3[n-2], e3[n-3]
    wire signed [FRAC_WIDTH+2:0] comp_3rd;
    reg [FRAC_WIDTH+2:0] Ec_d1 = 0, Ec_d2 = 0, Ec_d3 = 0;            // E_combined ????

    assign clk_delta_sigma = Fout;
	reg delta_sigma_d1 = 0;
	
	wire [1:0] eo_dly_sel;
	
	    always @(posedge Fout or negedge rst_n) begin
        if (!rst_n) begin
            Eo <= 'd0;
        end else begin
        	Eo <= (eo_dly_sel==2'b00) ? Eo_raw :
	            (eo_dly_sel==2'b01) ? Eo_d1 :
	            (eo_dly_sel==2'b10) ? Eo_d2 : Eo_d3;
        end 
    end

	
	
    // 3 ????? (????? negedge Fout):
    //   comp = e1[n-1] + (e2[n-1] - e2[n-2]) + (e3[n-1] - 2?e3[n-2] + e3[n-3])
    assign comp_3rd = $signed({1'b0, e1_r})
                    + $signed({1'b0, e2_r2}) - $signed({1'b0, e2_r3})
                    + $signed({1'b0, e3_r2})
                    - $signed({{2{1'b0}}, e3_r3}) - $signed({{2{1'b0}}, e3_r3})
                    + $signed({1'b0, e3_r4});

    always @(negedge Fout or negedge rst_n) begin
        if (!rst_n) begin
            delta_sigma_d1 <= 0;
            Eo_d1 <= 'd0;
            Eo_d2 <= 'd0;
            Eo_d3 <= 'd0;
            e1_r  <= 'd0;
            e2_r1 <= 'd0;
            e2_r2 <= 'd0;
            e2_r3 <= 'd0;
            e3_r1 <= 'd0;
            e3_r2 <= 'd0;
            e3_r3 <= 'd0;
            e3_r4 <= 'd0;
            Ec_d1 <= 'd0; Ec_d2 <= 'd0; Ec_d3 <= 'd0;
            E_combined <= 'd0;
            
        end else begin
            // 1 ????? (?)
            Eo_d1    <= Eo_raw;
            Eo_d2    <= Eo_d1;
            Eo_d3    <= Eo_d2;
            delta_sigma_d1 <= delta_sigma;
            
            // 3 ?????
            // mash_e2/mash_e3 ????? (??? e2[n], e3[n])
            // e2_r1/e3_r1 ?? 1 ???? e1_r (=Eo_raw = e1[n-1])
            e1_r  <= Eo_raw;      // e1[n-1]
            e2_r1 <= mash_e2;     // e2[n]
            e2_r2 <= e2_r1;       // e2[n-1]
            e2_r3 <= e2_r2;       // e2[n-2]
            e3_r1 <= mash_e3;     // e3[n]
            e3_r2 <= e3_r1;       // e3[n-1]
            e3_r3 <= e3_r2;       // e3[n-2]
            e3_r4 <= e3_r3;       // e3[n-3]

            Ec_d1 <= comp_3rd[FRAC_WIDTH+2:0];
            Ec_d2 <= Ec_d1;
            Ec_d3 <= Ec_d2;
            // E_combined ???? (?? eo_dly_sel, ? Eo ????? VIO)
            E_combined <= (eo_dly_sel==2'b00) ? comp_3rd[FRAC_WIDTH+2:0] :
                          (eo_dly_sel==2'b01) ? Ec_d1 :
                          (eo_dly_sel==2'b10) ? Ec_d2 : Ec_d3;
        end 
    end
    
    vio_eo u_vio_eo (
        .clk (Sys_clk),
        
        .probe_out0 (eo_dly_sel)
        );
        
    
    //assign Fout = Fout_reg;
    
	dff  u_sync_rstn_dff (
        .clk                     ( Fin      ),
        .LD                      ( 1'b0     ),
		.rst_n					 ( 1'b1		),
        .P                       ( 1'b1     ),
        .D                       ( rst_n    ),

        .Q                       ( rst_n_sync     ),
        .Qn                      (     )
    );

    // Sigma-Delta ??? (?????? EFM ????)
    mash111 #(
        .WIDTH  ( FRAC_WIDTH ),
        .A_GAIN ( 1  ))
    u_mash111 (
        .clk                     ( clk_delta_sigma ),
        .clk_ila                 ( Sys_clk         ),
        .rst_n                   ( rst_n_sync      ),
        .x_i                     ( Fraction        ),

        .y_o                     ( delta_sigma     ),
        .e_o                     ( Eo_raw          ),
        .e1_o                    ( mash_e1         ),
        .e2_o                    ( mash_e2         ),
        .e3_o                    ( mash_e3         )
    );

    // ????????? Sigma-Delta ????????????????????? P ???? S ???
    calculate_ps #(
        .P_WIDTH   ( P_WIDTH ),
        .S_WIDTH   ( S_WIDTH ),
        .INT_WIDTH ( INT_WIDTH ))
    u_calculate_ps (
        .clk                     ( ~clk_delta_sigma ),
        .rst_n                   ( rst_n_sync      ),
        .Integer                 ( Integer         ),
        .delta_sigma             ( delta_sigma_d1     ),
		.Ei						 ( Eo_raw		   ),
        .Si                      ( Si              ),
        .Pi                      ( Pi              ),
		.Eo						 (    		   )
    );
    
    // P/S ?????
    dual_div #(
        .P_WIDTH ( P_WIDTH ),
        .S_WIDTH ( S_WIDTH ))
    u_dual_div (
        .clk                     ( Fin        ),
        .clk_ila                 ( Sys_clk    ),
        .rst_n                   ( rst_n_sync ),
        .Si                      ( Si         ),
        .Pi                      ( Pi         ),

        .Fdiv                    ( Fout       )
    );    
    
endmodule`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// SSC (Spread Spectrum Clocking) ???????
// ?? fracn ?????????????????
// ????: 12.5MHz (?? 80ns)
// ??: ??? Fraction ???? MASH ?????
//
// ????: bypass ??
//   bypass = 1: ???? Integer/Fraction????
//   bypass = 0: ?? SSC ??
////////////////////////////////////////////////////////////////////////////////

module ssc_controller #(
    parameter MODULATION_FREQ = 30000,      // ???? 30kHz
    parameter SPREAD_PERCENT  = 50,         // ???? 0.5% (??: 0.01%)
    parameter FRAC_WIDTH      = 10,         // ????
    parameter INT_WIDTH       = 8           // ????
)(
    input  wire                  clk,       // 12.5MHz ????
    input  wire                  rst_n,
    input  wire                  bypass,     // 1: bypass ??, 0: SSC ??

    input  wire [INT_WIDTH-1:0]  Integer,   // ?????????
    input  wire [FRAC_WIDTH-1:0] Fraction,   // ????????? (??)

    output reg [INT_WIDTH-1:0] ssc_int = 0,   // ?????????
    output reg [FRAC_WIDTH-1:0] ssc_frac = 0,  // ?????????
    output reg                   ssc_en     // ????
);

    // ============================================================
    // ????
    // ============================================================
    localparam MOD_PERIOD = 12500000 / MODULATION_FREQ;  // 416 or 417
    localparam SPREAD_SCALE = SPREAD_PERCENT;
    localparam MAX_OFFSET = (65536 * SPREAD_PERCENT) / 10000;

    // ============================================================
    // ????????
    // ============================================================
    localparam MOD_CNT_WIDTH = $clog2(MOD_PERIOD);

    reg [MOD_CNT_WIDTH-1:0] mod_cnt;
    reg                     mod_dir;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mod_cnt <= {MOD_CNT_WIDTH{1'b0}};
            mod_dir <= 1'b0;
        end else if (!bypass) begin
            // ??? bypass ??????????
            if (mod_dir == 1'b0) begin
                if (mod_cnt >= MOD_PERIOD - 1) begin
                    mod_dir <= 1'b1;
                    mod_cnt <= mod_cnt - 1'b1;
                end else begin
                    mod_cnt <= mod_cnt + 1'b1;
                end
            end else begin
                if (mod_cnt == {MOD_CNT_WIDTH{1'b0}}) begin
                    mod_dir <= 1'b0;
                    mod_cnt <= mod_cnt + 1'b1;
                end else begin
                    mod_cnt <= mod_cnt - 1'b1;
                end
            end
        end else begin
            // bypass ??: ???????
            mod_cnt <= {MOD_CNT_WIDTH{1'b0}};
            mod_dir <= 1'b0;
        end
    end

    // ============================================================
    // ???????
    // ============================================================
    wire [FRAC_WIDTH-1:0] frac_offset;
    wire [FRAC_WIDTH+MOD_CNT_WIDTH-1:0] offset_mult;

    assign offset_mult = mod_cnt * MAX_OFFSET;
    assign frac_offset = offset_mult / MOD_PERIOD;

    // ============================================================
    // ????? (? bypass)
    // ============================================================
    wire [FRAC_WIDTH:0] frac_sum = {1'b0, Fraction} + {1'b0, frac_offset};
    wire                frac_carry = frac_sum[FRAC_WIDTH];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ssc_int  <= Integer;
            ssc_frac <= Fraction;
            ssc_en   <= 1'b0;
        end else if (bypass) begin
            // bypass ??: ???????
            ssc_int  <= Integer;
            ssc_frac <= Fraction;
            ssc_en   <= 1'b1;
        end else begin
            // SSC ??: ????
            ssc_en <= 1'b1;

            if (frac_carry) begin
                ssc_int  <= Integer + 1'b1;
                ssc_frac <= frac_sum[FRAC_WIDTH-1:0];
            end else begin
                ssc_int  <= Integer;
                ssc_frac <= frac_sum[FRAC_WIDTH-1:0];
            end
        end
    end

endmodule
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
    // 3b. ???? & ???????
    // -------------------------------------------------------------------------
    // cal_mode: ????????, ????? VIO
    // dtc_code: ???????? dtc_comp ??
    // dtc_code_cal: ????????? code????????
    wire cal_mode_sel;

    assign cal_mode_sel = cal_auto_en ? cal_mode_int : cal_mode;

    // dtc_code_pipe: ? Fout ????, ?? dtc_comp ??????? dtc_code_d1
    //   posedge Fout ??: 1?? Eo(posedge??) ????(??)
    //                       3?? E_combined(negedge??) ???????(??)
    //   ?? dtc_code_d1(negedge div_out_dtc_g) ??, ???Fout??, ??
    reg [8:0] dtc_code_pipe = 0;
    always @(posedge div_out_raw_g or negedge rst_n_dtc) begin
        if (!rst_n_dtc)
            dtc_code_pipe <= 9'd0;
        else
            dtc_code_pipe <= dtc_code;
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
`timescale 1ns / 1ps
module tb_quick_3rd;
    parameter SYS_CLK_PERIOD = 8.0;
    reg sys_clk_p = 0; reg sys_clk_n = 0; reg sys_rst;
	reg ideal_clk = 0;
    wire sma_ref_p, sma_ref_n, sma_dtc_p, sma_dtc_n;

    fpga_ssc_pll_top u_dut (
        .sys_clk_p(sys_clk_p), .sys_clk_n(sys_clk_n), .sys_rst(sys_rst),
        .sma_ref_p(sma_ref_p), .sma_ref_n(sma_ref_n),
        .sma_dtc_p(sma_dtc_p), .sma_dtc_n(sma_dtc_n));

    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n;
    always #(SYS_CLK_PERIOD*100.25/2) ideal_clk = ~ideal_clk;

    initial begin
        sys_rst = 1;
        #103 sys_rst = 0;
        #80000 sys_rst = 1;
        #1000 sys_rst = 0;
        #80000 sys_rst = 1;
        #1000 sys_rst = 0;
        #80000;
        $display("@%0t: DONE", $time);
        $finish;
    end

    initial begin
        $dumpfile("tb_quick_3rd.vcd");
        $dumpvars(0, tb_quick_3rd);
    end

    initial begin
        #200;
        forever begin
            #5000;
            $display("[%0t] sys_rst=%b state=%0d cal_mode=%b cal_done=%b cal_start=%b gain=%0d wait_cnt=%0d",
                $time, sys_rst,
                u_dut.u_cal.state, u_dut.u_cal.cal_mode,
                u_dut.cal_done, u_dut.u_vio_cal.cal_start_r,
                u_dut.dtc_gain_cal, u_dut.u_cal.wait_cnt);
        end
    end

    initial begin
        #250000;
        $display("@%0t: TIMEOUT", $time);
        $finish;
    end
endmodule
