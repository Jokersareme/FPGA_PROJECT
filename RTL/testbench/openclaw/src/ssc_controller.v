`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// SSC (Spread Spectrum Clocking) ???????
// ?? fracn ?????????????????
// ????: 12.5MHz (?? 80ns)
// ??: ??? Fraction ???? MASH ?????
//
// ????: bypass ??
//   bypass = 1: ???? Integer/Fraction????
//   bypass = 0: ?? SSC ??
////////////////////////////////////////////////////////////////////////////////

module ssc_controller #(
    parameter MODULATION_FREQ = 30000,      // ???? 30kHz
    parameter SPREAD_PERCENT  = 50,         // ???? 0.5% (??: 0.01%)
    parameter FRAC_WIDTH      = 10,         // ????
    parameter INT_WIDTH       = 8           // ????
)(
    input  wire                  clk,       // 12.5MHz ????
    input  wire                  rst_n,
    input  wire                  bypass,     // 1: bypass ??, 0: SSC ??

    input  wire [INT_WIDTH-1:0]  Integer,   // ?????????
    input  wire [FRAC_WIDTH-1:0] Fraction,   // ????????? (??)

    output reg [INT_WIDTH-1:0] ssc_int = 0,   // ?????????
    output reg [FRAC_WIDTH-1:0] ssc_frac = 0,  // ?????????
    output reg                   ssc_en     // ????
);

    // ============================================================
    // ????
    // ============================================================
    localparam MOD_PERIOD = 12500000 / MODULATION_FREQ;  // 416 or 417
    localparam SPREAD_SCALE = SPREAD_PERCENT;
    localparam MAX_OFFSET = (65536 * SPREAD_PERCENT) / 10000;

    // ============================================================
    // ????????
    // ============================================================
    localparam MOD_CNT_WIDTH = $clog2(MOD_PERIOD);

    reg [MOD_CNT_WIDTH-1:0] mod_cnt;
    reg                     mod_dir;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mod_cnt <= {MOD_CNT_WIDTH{1'b0}};
            mod_dir <= 1'b0;
        end else if (!bypass) begin
            // ??? bypass ??????????
            if (mod_dir == 1'b0) begin
                if (mod_cnt >= MOD_PERIOD - 1) begin
                    mod_dir <= 1'b1;
                    mod_cnt <= mod_cnt - 1'b1;
                end else begin
                    mod_cnt <= mod_cnt + 1'b1;
                end
            end else begin
                if (mod_cnt == {MOD_CNT_WIDTH{1'b0}}) begin
                    mod_dir <= 1'b0;
                    mod_cnt <= mod_cnt + 1'b1;
                end else begin
                    mod_cnt <= mod_cnt - 1'b1;
                end
            end
        end else begin
            // bypass ??: ???????
            mod_cnt <= {MOD_CNT_WIDTH{1'b0}};
            mod_dir <= 1'b0;
        end
    end

    // ============================================================
    // ???????
    // ============================================================
    wire [FRAC_WIDTH-1:0] frac_offset;
    wire [FRAC_WIDTH+MOD_CNT_WIDTH-1:0] offset_mult;

    assign offset_mult = mod_cnt * MAX_OFFSET;
    assign frac_offset = offset_mult / MOD_PERIOD;

    // ============================================================
    // ????? (? bypass)
    // ============================================================
    wire [FRAC_WIDTH:0] frac_sum = {1'b0, Fraction} + {1'b0, frac_offset};
    wire                frac_carry = frac_sum[FRAC_WIDTH];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ssc_int  <= Integer;
            ssc_frac <= Fraction;
            ssc_en   <= 1'b0;
        end else if (bypass) begin
            // bypass ??: ???????
            ssc_int  <= Integer;
            ssc_frac <= Fraction;
            ssc_en   <= 1'b1;
        end else begin
            // SSC ??: ????
            ssc_en <= 1'b1;

            if (frac_carry) begin
                ssc_int  <= Integer + 1'b1;
                ssc_frac <= frac_sum[FRAC_WIDTH-1:0];
            end else begin
                ssc_int  <= Integer;
                ssc_frac <= frac_sum[FRAC_WIDTH-1:0];
            end
        end
    end

endmodule
