`timescale 1ns / 1ps

module dtc_comp #(
    parameter WIDTH = 10,
    parameter DTC_WIDTH = 9
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire [WIDTH-1:0]  e1,
    input  wire [7:0]        dtc_gain,
    //input  wire [1:0]        dtc_offset_sel,  // 00=256, 01=300, 10=350, 11=400
    input  wire              dtc_en,
	input  wire [DTC_WIDTH-1:0] dtc_offset,
    output wire  [DTC_WIDTH-1:0] dtc_code,
    output reg               dtc_load
);

    wire dtc_code_man_en;
    wire [8:0] dtc_code_man;
    // 偏移量查找表（根据校准结果后续修改）
    //wire [DTC_WIDTH-1:0] dtc_offset;
    //assign dtc_offset = (dtc_offset_sel == 2'b00) ? 9'd000 :
    //                    (dtc_offset_sel == 2'b01) ? 9'd256 :
    //                    (dtc_offset_sel == 2'b10) ? 9'd350 : 9'd400;

    // 有符号乘法：e1(8bit) * gain(8bit) = 16bit
    // e1 范围 0~255，实际作为无符号量处理（只补偿幅度，方向由 carry 处理）
    wire [18:0] mult = e1 * 2'd2 * dtc_gain;

    // 取高 9 位 + 偏移，并做饱和
    wire [DTC_WIDTH-1:0] code_raw = mult[18:10] + dtc_offset;
    wire [DTC_WIDTH-1:0] code_sat = (code_raw > 9'd511) ? 9'd511 : code_raw;
    
    
    assign dtc_code = dtc_code_man_en ? dtc_code_man : code_sat;
    
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            dtc_code <= 9'd256;
//            dtc_load <= 1'b0;
//		end else if (!dtc_en) begin
//		    dtc_code <= 9'd256;
//            dtc_load <= 1'b0;
//        end else begin
//            dtc_code <= dtc_code_man_en ? dtc_code_man : code_sat;
//            dtc_load <= 1'b1; // 每周期都更新
//        end
//    end
    

    vio_1 u_vio_dtc_comp (
  .clk(clk),                // input wire clk
  .probe_out0(dtc_code_man_en),  // output wire [0 : 0] probe_out0
  .probe_out1(dtc_code_man)  // output wire [8 : 0] probe_out1
);


endmodule
