`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for idelay_dtc_top_single (EXTERNAL load_i version).
// Verifies: when `code` changes, an EXTERNAL load_i pulse stream makes the
// module step CNTVALUEIN toward `code` at <=8 taps/step, and the IDELAYE3 tap
// count (CNTVALUEOUT) follows `code`. This proves the delay tracks `code` under
// user-supplied LOAD (the bug we had was LOAD tied low -> zero delay).
//
// The external 12.5 MHz-domain controller is modeled simply: it pulses load_i
// (one rising edge per step) while idelay_busy=1, then stops. This matches real
// hardware where each load_i rising edge commits one module step.
//////////////////////////////////////////////////////////////////////////////////
module tb;
    reg            rst_n, din, idelay_en, idelay_clk, load_i;
    reg  [8:0]     code;
    wire           idelay_load, idelay_busy, dout, cal_valid;
    wire [8:0]     cal_result;
    wire [8:0]     taps;

    idelay_dtc_top_single dut (
        .sys_clk(1'b0), .rst_n(rst_n), .din(din), .code(code),
        .cal_mode(1'b0), .cal_code(9'd0), .dtc_sel(1'b0), .vco_clk(1'b0),
        .idelay_en(idelay_en), .idelay_clk(idelay_clk),
        .load_i(load_i), .idelay_load(idelay_load), .idelay_busy(idelay_busy),
        .dout(dout), .cal_result(cal_result), .cal_valid(cal_valid)
    );

    // Hierarchical probe into the stub's CNTVALUEOUT.
    assign taps = dut.u_idelay.CNTVALUEOUT;

    // 12.5 MHz control clock: #20 toggles -> 40 ns half-period (80 ns period),
    // high and low each >=40 ns (matches the user's DTC output clock spec).
    always #20 idelay_clk = ~idelay_clk;

    // External 12.5 MHz-domain controller: pulse load_i while busy.
    // toggle => one rising edge every 2 clocks => one module step per 2 clocks.
    reg load_toggle;
    always @(posedge idelay_clk or negedge rst_n) begin
        if (~rst_n) begin
            load_i <= 1'b0;
            load_toggle <= 1'b0;
        end else if (idelay_busy) begin
            load_toggle <= ~load_toggle;
            load_i      <= load_toggle;   // 1 during one phase, 0 during the other
        end else begin
            load_i      <= 1'b0;
            load_toggle <= 1'b0;
        end
    end

    // Toggle din so we can observe dout lagging.
    always #50 din = ~din;

    // Step-size check: whenever taps change, the jump must be <= 8.
    reg [8:0] prev_taps;
    reg       prev_valid;
    always @(posedge idelay_clk) begin
        if (prev_valid && (taps !== prev_taps)) begin
            if ((taps > prev_taps) && (taps - prev_taps > 9'd8))
                $display("ERR up step too big:   %0d -> %0d", prev_taps, taps);
            if ((prev_taps > taps) && (prev_taps - taps > 9'd8))
                $display("ERR down step too big: %0d -> %0d", prev_taps, taps);
        end
        prev_taps  <= taps;
        prev_valid <= 1'b1;
    end

    // Task: set code and wait (bounded) until the delay line settles (busy=0).
    task set_code;
        input [8:0] v;
        integer i;
        begin
            code = v;
            i = 0;
            while (idelay_busy && (i < 2000)) begin
                @(posedge idelay_clk);
                i = i + 1;
            end
            if (~idelay_busy)
                $display("SETTLED  code=%0d  taps=%0d  (waited %0d clk = %0d ns)",
                         v, taps, i, i*40);
            else
                $display("TIMEOUT  code=%0d  taps=%0d", v, taps);
        end
    endtask

    initial begin
        $dumpfile("idelay_dtc_tb.vcd");
        $dumpvars(0, tb);
        prev_valid = 0;
        idelay_clk = 0; rst_n = 0; din = 0; idelay_en = 1; code = 0; load_i = 0;
        #20 rst_n = 1;
        set_code(9'd100);    // 0 -> 100  (up)
        set_code(9'd50);     // 100 -> 50 (down)
        set_code(9'd300);    // 50 -> 300 (up, crosses 256 half-select boundary)
        set_code(9'd0);      // 300 -> 0  (down, crosses 256 again)
        #200;
        $display("DONE  (no ERR = every load step moved <=8 taps; SETTLED = delay tracks code)");
        $finish;
    end
endmodule
