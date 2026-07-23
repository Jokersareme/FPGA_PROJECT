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
