`timescale 1ns / 1ps
module lut_dtc #(parameter N_TAP=512, parameter CODE_WIDTH=9)(
    input wire sys_clk, input wire rst_n, input wire din,
    input wire [CODE_WIDTH-1:0] code, input wire cal_mode,
    input wire dtc_sel, output wire dout,
    output reg [CODE_WIDTH-1:0] cal_result, output reg cal_valid);
    assign dout = din;

    // ??TDC: ??CARRY8????
    // 20ps/tap, VCO??=1600ps, ???? = code*20/1600 = code/80
    reg [8:0] tdc_cnt = 0;
    reg [8:0] tdc_code = 0;
    reg tdc_busy = 0;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            cal_valid <= 1'b0; cal_result <= 0;
            tdc_cnt <= 0; tdc_code <= 0; tdc_busy <= 0;
        end else if (cal_mode && !tdc_busy) begin
            tdc_code <= code;
            tdc_cnt <= code / 80;  // ??VCO???
            tdc_busy <= 1;
            cal_valid <= 1'b0;
        end else if (tdc_busy) begin
            if (tdc_cnt == 0) begin
                tdc_busy <= 0;
                cal_valid <= 1'b1;
                cal_result <= tdc_code / 80;
            end else begin
                tdc_cnt <= tdc_cnt - 1;
                cal_valid <= 1'b0;
            end
        end else begin
            cal_valid <= 1'b0;
        end
    end
endmodule
