`timescale 1ns / 1ps

// ============================================================
// Xilinx Primitive Simulation Models for Icarus Verilog
// ============================================================

module IBUFDS #(parameter DIFF_TERM="FALSE", parameter IBUF_LOW_PWR="TRUE", parameter IOSTANDARD="DEFAULT") (output O, input I, input IB);
    assign #1.0 O = I;
endmodule

module OBUFDS #(parameter IOSTANDARD="DEFAULT", parameter SLEW="SLOW") (output O, output OB, input I);
    assign #1.0 O = I;
    assign #1.0 OB = ~I;
endmodule

module BUFG (output O, input I);
    assign #0.5 O = I;
endmodule

module BUFGMUX #(parameter CLK_SEL_TYPE="SYNC") (output O, input I0, input I1, input S);
    assign #0.5 O = S ? I1 : I0;
endmodule

// VIO stubs
module vio_0 (
    input clk,
    input [0:0] probe_in0,
    input [0:0] probe_in1,
    output [7:0] probe_out0,
    output [9:0] probe_out1,
    output [9:0] probe_out2,
    output [2:0] probe_out3,
    output [9:0] probe_out4,
    output [8:0] probe_out5,
    output [0:0] probe_out6
);
    // Default values for simulation:
    // int_div=71, frac=213, dtc_gain=160, dtc_en=1, ref_div_cnt_cmp=12, dtc_offset=0, cal_mode=0
    assign probe_out0 = 8'd100;
    assign probe_out1 = 10'd3;
    assign probe_out2 = 10'd100;
    assign probe_out3 = 3'd1;
    assign probe_out4 = 10'd12;
    assign probe_out5 = 9'd0;
    assign probe_out6 = 1'd0;
endmodule

module vio_cal (
    input clk,
    output probe_out0,
    output probe_out1,
    output probe_out2,
    input [9:0] probe_in0,
    input [0:0] probe_in1
);
    reg [15:0] cnt = 0;
    reg cal_start_r = 0;

    // cal_auto_en=0 (manual mode)
    // order_sel=0 (1st-order compensation)
    assign probe_out0 = cal_start_r;
    assign probe_out1 = 1'b0;
    assign probe_out2 = 1'b1;

    // Trigger calibration ~1us after reset
    always @(posedge clk) begin
        if (cnt < 16'd125) begin
            cnt <= cnt + 1;
        end else if (cnt == 16'd125) begin
            cal_start_r <= 1'b1;
            cnt <= cnt + 1;
        end else if (probe_in1) begin
            cal_start_r <= 1'b0;
        end else if (cnt > 16'd5000) begin
            cal_start_r <= 1'b0;
        end else begin
            cnt <= cnt + 1;
        end
    end
endmodule

module vio_rst (
    input clk,
    output [0:0] probe_out0,
    output [0:0] probe_out1,
    output [0:0] probe_out2,
    output [0:0] probe_out3
);
    reg rst_out = 0;
    assign probe_out0 = 1'b1;
    assign probe_out1 = 1'b1;
    assign probe_out3 = 1'b1;
    assign probe_out2 = rst_out;
    initial begin
        rst_out = 0;
        #20 rst_out = 1;
    end
endmodule

module test_clk (
    input clk,
    output [2:0] probe_out0,
    output [2:0] probe_out1
);
    assign probe_out0 = 3'd0;
    assign probe_out1 = 3'd0;
endmodule

module vio_eo (
    input clk,
    output [1:0] probe_out0
);
    assign probe_out0 = 2'd0;
endmodule

module vio_1 (
    input clk,
    output [0:0] probe_out0,
    output [9:0] probe_out1
);
    assign probe_out0 = 1'b0;
    assign probe_out1 = 10'd0;
endmodule

module mash_stage (
    input clk,
    output [1:0] probe_out0,
    output [1:0] probe_out1
);
    assign probe_out0 = 2'd2;
    assign probe_out1 = 2'd2;
endmodule

// ILA stubs
module ila_0 (
    input clk,
    input [0:0] probe0,
    input [0:0] probe1,
    input [9:0] probe2,
    input [2:0] probe3,
    input [8:0] probe4,
    input [8:0] probe5,
    input [0:0] probe6
);
endmodule

module ila_1 (
    input clk,
    input [9:0] probe0,
    input [9:0] probe1,
    input [9:0] probe2,
    input [9:0] probe3,
    input [3:0] probe4
);
endmodule

module ila_dualdiv (
    input clk,
    input [5:0] probe0,
    input [1:0] probe1,
    input [1:0] probe2,
    input [1:0] probe3,
    input [3:0] probe4,
    input [0:0] probe5
);
endmodule

// MMCM/PLL model
module clk_wiz_0 (
    input clkfb_in,
    output clk_out1,
    output clkfb_out,
    input reset,
    output locked,
    input clk_in1
);
    reg clk_out_r = 0;
    reg locked_r = 0;
    reg [15:0] lock_cnt = 0;

    // ~625MHz output (1.6ns period)
    always begin
        #0.8 clk_out_r = 1;
        #0.8 clk_out_r = 0;
    end

    always @(posedge clk_in1 or posedge reset) begin
        if (reset) begin
            lock_cnt <= 0;
            locked_r <= 0;
        end else if (!locked_r) begin
            if (lock_cnt < 16'd80)
                lock_cnt <= lock_cnt + 1;
            else
                locked_r <= 1;
        end
    end

    assign #0.2 clk_out1 = clk_out_r;
    assign #0.2 clkfb_out = clk_out_r;
    assign locked = locked_r;
endmodule

// IDELAYE3: Behavioral model
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
    input CLK,
    input CE,
    input CASC_IN,
    input CASC_RETURN,
    input IDATAIN,
    input DATAIN,
    input INC,
    input LOAD,
    input [8:0] CNTVALUEIN,
    output [8:0] CNTVALUEOUT,
    output DATAOUT,
    output CASC_OUT,
    input EN_VTC,
    input RST
);
    reg [8:0] delay_val = 0;
    reg dataout_r = 0;

    always @(posedge CLK or posedge RST) begin
        if (RST)
            delay_val <= 0;
        else if (LOAD)
            delay_val <= CNTVALUEIN;
    end

    // Variable delay: 40ps per tap
    always @(DATAIN or RST or delay_val) begin
        if (RST)
            dataout_r = 0;
        else
            dataout_r = #(delay_val * 0.040) DATAIN;
    end

    assign DATAOUT = dataout_r;
    assign CNTVALUEOUT = delay_val;
    assign CASC_OUT = 1'b0;
endmodule

// IDELAYCTRL stub
module IDELAYCTRL #(parameter SIM_DEVICE = "ULTRASCALE")(
    input REFCLK,
    input RST,
    output RDY
);
    reg rdy_r = 0;
    reg [7:0] cnt = 0;
    always @(posedge REFCLK or posedge RST) begin
        if (RST) begin
            cnt <= 0;
            rdy_r <= 0;
        end else if (cnt < 100) begin
            cnt <= cnt + 1;
            rdy_r <= 0;
        end else begin
            rdy_r <= 1;
        end
    end
    assign RDY = rdy_r;
endmodule
