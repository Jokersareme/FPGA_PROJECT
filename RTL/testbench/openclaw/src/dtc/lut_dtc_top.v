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

