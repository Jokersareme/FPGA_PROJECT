import os, re
os.chdir(r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw")

# Read source lut_dtc_top
with open(r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\all\dtc\lut_dtc_top.v", "r") as f:
    src = f.read()

# Strip synthesis attributes
src = re.sub(r'\(\*\s*(DONT_TOUCH|KEEP)\s*=\s*"TRUE"\s*\*\)\s*', '', src)

# Fix din_rise
src = src.replace("wire din_rise = din_d1 && !din_d2;", "wire din_rise = din && !din_d2;")

# Add IDELAYE3 ports
src = src.replace(
    "    input  wire              vco_clk,",
    "    input  wire              vco_clk,\n    input  wire              idelay_en,\n    input  wire              idelay_clk,\n    output wire              idelay_load,"
)

# Rename dout to carry_dout + add wire
src = src.replace("wire [4:0] div_out_dtc_i;", "wire [4:0] div_out_dtc_i;\nwire carry_dout;")
src = src.replace("assign dout = (dtc_sel == 0) ? div_out_dtc_i[1] : div_out_dtc_i[4];",
                   "assign carry_dout = (dtc_sel == 0) ? div_out_dtc_i[1] : div_out_dtc_i[4];")

# Behavioral TDC delay model
src = src.replace(
    "wire din_delayed = cal_dtc_i[16];",
    "reg [15:0] tdc_delay; reg din_delayed = 0;\n"
    "always @(posedge vco_clk or negedge rst_n) begin\n"
    "    if (!rst_n) begin tdc_delay <= 0; din_delayed <= 0; end\n"
    "    else if (cal_mode_m2 && din_rise) begin\n"
    "        tdc_delay <= dtc_code; din_delayed <= 0;\n"
    "    end else if (tdc_delay > 0) begin\n"
    "        tdc_delay <= tdc_delay - 1;\n"
    "        if (tdc_delay == 1) din_delayed <= 1;\n"
    "    end else if (!cal_mode_m2) begin\n"
    "        din_delayed <= 0;\n"
    "    end\n"
    "end"
)

# Add IDELAYE3 and output MUX
insert_point = ".dout(div_out_dtc_i[4]), .cal_result(), .cal_valid());\n\n    genvar i;"
idelaye3_code = """.dout(div_out_dtc_i[4]), .cal_result(), .cal_valid());

    // IDELAYE3 path
    wire idelay_dout;
    assign idelay_load = 1'b1;
    assign dout = idelay_en ? idelay_dout : carry_dout;

    IDELAYE3 #(
        .CASCADE("NONE"), .DELAY_FORMAT("TIME"), .DELAY_SRC("DATAIN"),
        .DELAY_TYPE("VAR_LOAD"), .DELAY_VALUE(0),
        .IS_CLK_INVERTED(1'b0), .IS_RST_INVERTED(1'b0),
        .REFCLK_FREQUENCY(300.0), .SIM_DEVICE("ULTRASCALE_PLUS"), .UPDATE_MODE("ASYNC")
    ) u_idelaye3 (
        .CLK(idelay_clk), .CE(1'b0), .CASC_IN(1'b0), .CASC_RETURN(1'b0),
        .IDATAIN(1'b0), .DATAIN(din), .INC(1'b0), .LOAD(idelay_load),
        .CNTVALUEIN({{(9-CODE_WIDTH){1'b0}}, code}), .CNTVALUEOUT(),
        .DATAOUT(idelay_dout), .CASC_OUT(), .EN_VTC(1'b1), .RST(~rst_n)
    );

    genvar i;"""

src = src.replace(insert_point, idelaye3_code)

# Write
with open("src/dtc/lut_dtc_top.v", "w", encoding="ascii") as f:
    f.write(src)

print("Done")
