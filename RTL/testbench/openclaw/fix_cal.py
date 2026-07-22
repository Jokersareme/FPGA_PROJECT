import os
os.chdir(r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw")
src = r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\all\dtc\dtc_calibrator.v"
with open(src, "r", encoding="utf-8") as f:
    content = f.read()

sm_min = """                SM_MIN_MEAS: begin
                    cal_mode <= 1'b1; wait_cnt <= 0;
                end"""
sm_min_fix = """                SM_MIN_MEAS: begin
                    cal_mode <= 1'b1; wait_cnt <= wait_cnt + 1'b1;
                end"""

sm_max = """                SM_MAX_MEAS: begin
                    cal_mode <= 1'b1; wait_cnt <= 0;
                end"""
sm_max_fix = """                SM_MAX_MEAS: begin
                    cal_mode <= 1'b1; wait_cnt <= wait_cnt + 1'b1;
                end"""

content = content.replace(sm_min, sm_min_fix)
content = content.replace(sm_max, sm_max_fix)

with open(src, "w", encoding="utf-8", newline="\n") as f:
    f.write(content)
print("Source FIXED")
