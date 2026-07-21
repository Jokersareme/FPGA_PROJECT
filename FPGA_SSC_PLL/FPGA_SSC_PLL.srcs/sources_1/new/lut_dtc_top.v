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
    input  wire              dtc_sel,
    input  wire              vco_clk,
    output wire              dout,
    output wire  [CODE_WIDTH-1:0] cal_result,
    output wire               cal_valid
);

wire [2:0] div_out_dtc_i;
wire [19:0] cal_dtc_i;
wire [CODE_WIDTH-1:0] dtc_code;

assign div_out_dtc_i[0] = din;
assign cal_dtc_i[0] = din;
assign dout = (dtc_sel == 0) ? div_out_dtc_i[1] : div_out_dtc_i[2];
assign dtc_code = code;

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

            (* DONT_TOUCH = "TRUE" *)
            lut_dtc #(
            .N_TAP (512),
            .CODE_WIDTH (9)
        ) u_lut_dtc_dly2 (
                     .sys_clk       (sys_clk),
                     .rst_n         (rst_n),
                     .din           (div_out_dtc_i[1]),
                     .code          (dtc_code),
                     .cal_mode      (1'b0),
                     .dtc_sel       (1'b0),
                     .dout          (div_out_dtc_i[2]),
                     .cal_result    (),
                     .cal_valid     ()
            );

    genvar i;
    generate
        for (i = 1; i < 17; i = i + 1) begin : cascade
            (* DONT_TOUCH = "TRUE" *)
            lut_dtc #(
            .N_TAP (512),
            .CODE_WIDTH (9)
        ) u_lut_dtc (
                     .sys_clk       (sys_clk),
                     .rst_n         (rst_n),
                     .din           (cal_dtc_i[i-1]),
                     .code          (dtc_code),
                     .cal_mode      (1'b0),
                     .dtc_sel       (1'b0),
                     .dout          (cal_dtc_i[i]),
                     .cal_result    (),
                     .cal_valid     ()
            );
        end
    endgenerate


// ============================================================
    // TDC 延迟测量模块
    // 测量 din 上升沿到 din_delayed 上升沿的 sys_clk 周期数
    // ============================================================
    localparam TDC_WIDTH   = 9;
     
    reg din_d1, din_d2;           // din 同步寄存器
    reg din_delayed_d1, din_delayed_d2;  // din_delayed 同步寄存器
    reg [TDC_WIDTH-1:0] tdc_counter;     // 计数器
    reg [TDC_WIDTH-1:0] tdc_count;     // 计数器
    reg tdc_measuring;                    // 测量中标志
    reg tdc_valid;                    // 测量中标志
    
    
    
    wire din_delayed_pre = cal_dtc_i[0];
    wire din_delayed     = cal_dtc_i[16];
    

    // 边沿检测
    wire din_rise = din_d1 && !din_d2;              // din 上升沿
    wire din_delayed_rise = din_delayed_d1 && !din_delayed_d2;  // din_delayed 上升沿

    always @(posedge vco_clk or negedge rst_n) begin
        if (!rst_n) begin
            din_d1 <= 1'b0;
            din_d2 <= 1'b0;
            din_delayed_d1 <= 1'b0;
            din_delayed_d2 <= 1'b0;
            tdc_counter <= {TDC_WIDTH{1'b0}};
            tdc_measuring <= 1'b0;
            tdc_count <= {TDC_WIDTH{1'b0}};
            tdc_valid <= 1'b0;
        end else begin
            // 同步输入
            din_d1 <= din_delayed_pre;
            din_d2 <= din_d1;
            din_delayed_d1 <= din_delayed;
            din_delayed_d2 <= din_delayed_d1;

            // 测量逻辑
            if (cal_mode && tdc_valid) begin
            
                tdc_valid <= tdc_valid;
                tdc_count <= tdc_count;
            
            end else if (cal_mode) begin
                if (din_rise) begin
                    // din 上升沿: 开始计数
                    tdc_counter <= {{(TDC_WIDTH-1){1'b0}}, 1'b1};  // 从1开始
                    tdc_measuring <= 1'b1;
                    tdc_valid <= 1'b0;
                end else if (tdc_measuring) begin
                    if (din_delayed_rise) begin
                        // din_delayed 上升沿: 结束计数, 输出结果
                        tdc_count <= tdc_counter;
                        tdc_valid <= 1'b1;
                        tdc_measuring <= 1'b0;
                    end else begin
                        // 继续计数
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

    assign cal_result = tdc_counter;
    assign cal_valid  = tdc_valid;
    

endmodule

