import os
os.chdir(r"D:\GS\项目\FPGA\xcvu9p-flga2104-2L-e\fpga_pll_mash111_dtc_ssc\RTL\testbench\openclaw")

with open("tb_top.v", "r", encoding="utf-8") as f:
    c = f.read()

# Remove old monitor
old_mon = """    initial begin
        #100000;
        forever begin
            #50000;
            $display(\"[%0t] locked=%b | cal_done=%b | gain=%0d | dtc_code=%0d\",
                     $time, u_dut.u_mmcm_pll.locked, u_dut.cal_done, u_dut.dtc_gain_muxed, u_dut.dtc_code);
        end
    end"""

new_mon = """    // Edge timing analysis
    reg [63:0] ref_min=1000000000, ref_max=0, ref_total=0, ref_cnt=0, ref_edges=0, ref_last=0;
    reg [63:0] dtc_min=1000000000, dtc_max=0, dtc_total=0, dtc_cnt=0, dtc_edges=0, dtc_last=0;

    always @(posedge u_dut.div_out_raw) begin
        if (ref_last != 0 && ref_edges > 100 && ref_edges <= 200) begin
            ref_cnt <= ref_cnt + 1;
            ref_total <= ref_total + ($time - ref_last);
            if ($time - ref_last < ref_min) ref_min <= $time - ref_last;
            if ($time - ref_last > ref_max) ref_max <= $time - ref_last;
        end
        ref_last <= $time; ref_edges <= ref_edges + 1;
    end

    always @(posedge sma_ref_p) begin
        if (dtc_last != 0 && dtc_edges > 100 && dtc_edges <= 200) begin
            dtc_cnt <= dtc_cnt + 1;
            dtc_total <= dtc_total + ($time - dtc_last);
            if ($time - dtc_last < dtc_min) dtc_min <= $time - dtc_last;
            if ($time - dtc_last > dtc_max) dtc_max <= $time - dtc_last;
        end
        dtc_last <= $time; dtc_edges <= dtc_edges + 1;
    end

    initial begin
        #1800000;
        $display("");
        $display("=== Jitter Analysis (100 periods) ===");
        $display("--- Reference (div_out_raw) ---");
        if (ref_cnt > 0) begin
            $display("  Avg period: %0d ps (%.2f ns)", ref_total/ref_cnt, (ref_total/ref_cnt)/1000.0);
            $display("  Min: %0d ps  Max: %0d ps", ref_min, ref_max);
            $display("  Jitter p-p: %0d ps  (%.1f%%)", ref_max-ref_min, (ref_max-ref_min)*100.0/(ref_total/ref_cnt));
        end
        $display("--- DTC compensated (sma_ref_p) ---");
        if (dtc_cnt > 0) begin
            $display("  Avg period: %0d ps (%.2f ns)", dtc_total/dtc_cnt, (dtc_total/dtc_cnt)/1000.0);
            $display("  Min: %0d ps  Max: %0d ps", dtc_min, dtc_max);
            $display("  Jitter p-p: %0d ps  (%.1f%%)", dtc_max-dtc_min, (dtc_max-dtc_min)*100.0/(dtc_total/dtc_cnt));
            $display("  Freq: %.2f MHz", 1000000.0/(dtc_total/(dtc_cnt*1000)));
        end
        $display("Expected: 625MHz / (71+213/1024) = %.2f MHz", 625.0/(71+213.0/1024.0));
        $finish;
    end"""

c = c.replace(old_mon, new_mon)

# Remove old timeout (our analysis has its own)
old_to = "    initial begin\n        #2000000; // 2ms timeout\n        $display(\"TIMEOUT\");\n        $finish;\n    end"
new_to = "    initial begin #2500000; $finish; end"
c = c.replace(old_to, new_to)

with open("tb_top.v", "w", encoding="utf-8") as f:
    f.write(c)
print("Written")
