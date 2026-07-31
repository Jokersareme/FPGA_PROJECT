`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/27 09:45:38
// Design Name: 
// Module Name: dtc_cal_top
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

(* DONT_TOUCH = "TRUE" *)
module dtc_cal_top(
    input wire       sys_clk,
    input wire       clk_ref,
    input wire       clk_fb,
    input wire       rst_n,
    input wire [8:0] dtc_code,
    output wire [9:0] dtc_cal_out_gain

    );
    
    
    wire pd_sign; // 0 for ref pre , 1 for fb pre
    wire clk_ref_dly; 
    wire clk_fb_dly; 
    reg [8:0] dtc_code_d1=0; 
    wire [8:0] delay_code; 
    reg [19:0] wait_time=0; 
    reg cal_start=0; 
    
    always @(posedge clk_fb or negedge rst_n) begin
    if (!rst_n) begin
        dtc_code_d1 <= 'd0;
        wait_time <= 'd0;
        cal_start <= 1'b0;
    end else begin
        dtc_code_d1 <= dtc_code;
        if (wait_time <= 20'hfffff) begin
            wait_time <= wait_time + 1'b1;
            cal_start <= 1'b1;
        end else begin
            wait_time <= wait_time;
            cal_start <= cal_start;
        end
    end
    end
    
    
    (* DONT_TOUCH = "TRUE" *)
    lut_dtc #(
        .N_TAP (512),
        .CODE_WIDTH (9)
    ) u_dtc_cal_dly_ref (
                 .sys_clk       (sys_clk),
                 .rst_n         (rst_n),
                 .din           (clk_ref),
                 .code          (delay_code),
                 .cal_mode      (1'b0),
                 .dtc_sel       (1'b0),
                 .dout          (clk_ref_dly),
                 .cal_result    (),
                 .cal_valid     ()
        );
        
        
    (* DONT_TOUCH = "TRUE" *)
    lut_dtc #(
        .N_TAP (512),
        .CODE_WIDTH (9)
    ) u_dtc_cal_dly_fb (
                 .sys_clk       (sys_clk),
                 .rst_n         (rst_n),
                 .din           (clk_fb),
                 .code          (9'd255),
                 .cal_mode      (1'b0),
                 .dtc_sel       (1'b0),
                 .dout          (clk_fb_dly),
                 .cal_result    (),
                 .cal_valid     ()
        );
    
    
    phase_align_cal u_bbpd_cal (
        .clk          (~clk_ref_dly),
        .rst_n        (rst_n),
        .sign_in      (pd_sign),
        .delay_code   (delay_code)
    );

    cal_sign_gen u_bbpd (
        .clk_ref     (clk_ref_dly),
        .clk_fb      (clk_fb_dly),
        .rst_n       (rst_n),
        .sign        (pd_sign)
    
    ); 
    
    dtc_gain_lms_cal u_lms_cal (
        .clk                    (~clk_fb_dly),           
        .rst_n                  (cal_start),         
        .sign_in                (pd_sign),       
     
        .dtc_code_in            (dtc_code_d1),   
        .gain_base              (10'd512),    
        .gain_corrected         (dtc_cal_out_gain)
    );
    

    ila_cal_top u_ila_cal_top (
        .clk(sys_clk), // input wire clk
    
    
        .probe0(rst_n), // input wire [0:0]  probe0  
        .probe1(clk_ref_dly), // input wire [0:0]  probe1 
        .probe2(clk_fb_dly), // input wire [0:0]  probe2 
        .probe3(dtc_code), // input wire [8:0]  probe3 
        .probe4(dtc_cal_out_gain), // input wire [9:0]  probe4 
        .probe5(pd_sign), // input wire [0:0]  probe5
        .probe6(delay_code) // input wire [0:0]  probe5
    );

    
endmodule
