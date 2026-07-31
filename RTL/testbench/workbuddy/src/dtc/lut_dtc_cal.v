`timescale 1ns / 1ps
//
// Zero-delay calibration chain model (no CARRY8 instances)
// Used in lut_dtc_top for the 16-stage calibration path only.
// Main DTC path uses full CARRY8-based lut_dtc.
//
module lut_dtc_cal #(
    parameter CODE_WIDTH = 9
)(
    input  wire                  sys_clk,
    input  wire                  rst_n,
    input  wire                  din,
    input  wire [CODE_WIDTH-1:0] code,
    output wire                  dout,
    output reg  [CODE_WIDTH-1:0] cal_result,
    output reg                   cal_valid
);

    // Zero-delay pass-through for calibration chain
    assign dout = din;

    // TDC behavior model: 16-stage cascade at 40ps/tap
    // Total delay = 16 * code * 40ps
    // VCO ~625MHz (1.6ns) -> cal_result = 16*code*40ps/1600ps = (code*2)/5
    reg [8:0] tdc_cnt  = 0;
    reg [8:0] tdc_code = 0;
    reg       tdc_busy = 0;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            cal_valid  <= 1'b0;
            cal_result <= 0;
            tdc_cnt    <= 0;
            tdc_code   <= 0;
            tdc_busy   <= 0;
        end else if (1'b1 && !tdc_busy) begin  // cal_mode is always active for measurement
            tdc_code   <= code;
            tdc_cnt    <= (code * 2) / 5;
            tdc_busy   <= 1;
            cal_valid  <= 1'b0;
        end else if (tdc_busy) begin
            if (tdc_cnt == 0) begin
                tdc_busy   <= 0;
                cal_valid  <= 1'b1;
                cal_result <= (tdc_code * 2) / 5;
            end else begin
                tdc_cnt    <= tdc_cnt - 1;
                cal_valid  <= 1'b0;
            end
        end else begin
            cal_valid <= 1'b0;
        end
    end

endmodule
