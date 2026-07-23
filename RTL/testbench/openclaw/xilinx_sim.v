`timescale 1ns / 1ps
module IBUFDS #(parameter DIFF_TERM="FALSE", parameter IBUF_LOW_PWR="TRUE", parameter IOSTANDARD="DEFAULT") (output O, input I, input IB);
    assign O = I;
endmodule
module OBUFDS #(parameter IOSTANDARD="DEFAULT", parameter SLEW="SLOW") (output O, output OB, input I);
    assign O = I; assign OB = ~I;
endmodule
module BUFG (output O, input I);
    assign O = I;
endmodule
module BUFGMUX #(parameter CLK_SEL_TYPE="SYNC") (output O, input I0, input I1, input S);
    assign O = S ? I1 : I0;
endmodule
// VIO stubs
module vio_0 (input clk, input [0:0] probe_in0, input [0:0] probe_in1, output [7:0] probe_out0, output [9:0] probe_out1, output [9:0] probe_out2, output [2:0] probe_out3, output [9:0] probe_out4, output [8:0] probe_out5, output [0:0] probe_out6);
    assign probe_out0 = 8'd71; assign probe_out1 = 10'd213; assign probe_out2 = 10'd200;
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
    assign probe_out0 = 2'd0;
endmodule
module test_clk (input clk, output [2:0] probe_out0, output [2:0] probe_out1);
    assign probe_out0 = 3'd0; assign probe_out1 = 3'd0;
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
