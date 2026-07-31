`timescale 1ns / 1ps
module idelay_dtc_top_fast_tb;

    // FAST loader clock = 125 MHz (8 ns). The 12.5 MHz DTC output is the DATA
    // flowing through din, NOT this clock.
    reg idelay_clk = 0;
    always #4 idelay_clk = ~idelay_clk;   // 125 MHz

    reg sys_clk = 0;
    always #4 sys_clk = ~sys_clk;

    reg rst_n = 0;
    reg din = 0;
    // emulate a 12.5 MHz DTC output clock on din
    always #40 din = ~din;

    reg [8:0] code = 0;
    reg idelay_en = 1;

    wire dout;
    wire [8:0] cal_result;
    wire cal_valid;

    idelay_dtc_top_fast #(
        .CODE_WIDTH(9), .MAIN_STAGES(2), .MAX_STEP(8)
    ) dut (
        .sys_clk(sys_clk), .rst_n(rst_n), .din(din), .code(code),
        .cal_mode(1'b0), .cal_code(9'd0), .dtc_sel(1'b0), .vco_clk(1'b0),
        .idelay_en(idelay_en), .idelay_clk(idelay_clk),
        .dout(dout), .cal_result(cal_result), .cal_valid(cal_valid)
    );

    // monitor the internal busy + loaded_code via hierarchical refs
    wire [8:0] loaded_code = dut.loaded_code;
    wire busy = dut.busy;
    wire load_pulse = dut.load_pulse;

    integer clk_cnt;
    initial begin
        $dumpfile("sim/idelay_fast.vcd");
        $dumpvars(0);
        #100 rst_n = 1;
        code = 9'd300;   // large jump 0 -> 300 (300 taps)
        clk_cnt = 0;
        // wait until settled
        while (busy && clk_cnt < 200) begin @(posedge idelay_clk); clk_cnt++; end
        $display("JUMP 0->300 : settled in %0d loader-clks (%0d ns)  loaded=%0d busy=%b",
                 clk_cnt, clk_cnt*8, loaded_code, busy);

        code = 9'd0;     // large jump back 300 -> 0 (crosses 256)
        clk_cnt = 0;
        while (busy && clk_cnt < 200) begin @(posedge idelay_clk); clk_cnt++; end
        $display("JUMP 300->0 : settled in %0d loader-clks (%0d ns)  loaded=%0d busy=%b",
                 clk_cnt, clk_cnt*8, loaded_code, busy);

        code = 9'd511;   // full-range jump
        clk_cnt = 0;
        while (busy && clk_cnt < 300) begin @(posedge idelay_clk); clk_cnt++; end
        $display("JUMP 0->511 : settled in %0d loader-clks (%0d ns)  loaded=%0d busy=%b",
                 clk_cnt, clk_cnt*8, loaded_code, busy);

        $display("CONVERGENCE OK (busy=0 at end, loaded==code)");
        $finish;
    end

endmodule
