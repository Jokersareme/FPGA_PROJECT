`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// SSC (Spread Spectrum Clocking) 扩频时钟控制器
// 控制 fracn 小数分频比，实现中心扩频或向下扩频
// 输入时钟: 12.5MHz (周期 80ns)
// 输出: 变化的 Fraction 值，驱动 MASH 小数分频器
//
// 新增功能: bypass 模式
//   bypass = 1: 直接输出 Integer/Fraction，不扩频
//   bypass = 0: 正常 SSC 扩频
////////////////////////////////////////////////////////////////////////////////

module ssc_controller #(
    parameter MODULATION_FREQ = 30000,      // 调制频率 30kHz
    parameter SPREAD_PERCENT  = 50,         // 扩频深度 0.5% (单位: 0.01%)
    parameter FRAC_WIDTH      = 10,         // 小数位宽
    parameter INT_WIDTH       = 8           // 整数位宽
)(
    input  wire                  clk,       // 12.5MHz 参考时钟
    input  wire                  rst_n,
    input  wire                  bypass,     // 1: bypass 模式, 0: SSC 模式

    input  wire [INT_WIDTH-1:0]  Integer,   // 中心分频比整数部分
    input  wire [FRAC_WIDTH-1:0] Fraction,   // 中心分频比小数部分 (固定)

    output reg  [INT_WIDTH-1:0]  ssc_int,   // 扩频后的整数分频比
    output reg  [FRAC_WIDTH-1:0] ssc_frac,  // 扩频后的小数分频比
    output reg                   ssc_en     // 扩频使能
);

    // ============================================================
    // 参数计算
    // ============================================================
    localparam MOD_PERIOD = 12500000 / MODULATION_FREQ;  // 416 or 417
    localparam SPREAD_SCALE = SPREAD_PERCENT;
    localparam MAX_OFFSET = (65536 * SPREAD_PERCENT) / 10000;

    // ============================================================
    // 三角波调制生成器
    // ============================================================
    localparam MOD_CNT_WIDTH = $clog2(MOD_PERIOD);

    reg [MOD_CNT_WIDTH-1:0] mod_cnt;
    reg                     mod_dir;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mod_cnt <= {MOD_CNT_WIDTH{1'b0}};
            mod_dir <= 1'b0;
        end else if (!bypass) begin
            // 只有非 bypass 模式才运行调制计数器
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
            // bypass 模式: 复位调制计数器
            mod_cnt <= {MOD_CNT_WIDTH{1'b0}};
            mod_dir <= 1'b0;
        end
    end

    // ============================================================
    // 扩频偏移量计算
    // ============================================================
    wire [FRAC_WIDTH-1:0] frac_offset;
    wire [FRAC_WIDTH+MOD_CNT_WIDTH-1:0] offset_mult;

    assign offset_mult = mod_cnt * MAX_OFFSET;
    assign frac_offset = offset_mult / MOD_PERIOD;

    // ============================================================
    // 分频比合成 (带 bypass)
    // ============================================================
    wire [FRAC_WIDTH:0] frac_sum = {1'b0, Fraction} + {1'b0, frac_offset};
    wire                frac_carry = frac_sum[FRAC_WIDTH];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ssc_int  <= Integer;
            ssc_frac <= Fraction;
            ssc_en   <= 1'b0;
        end else if (bypass) begin
            // bypass 模式: 直接输出中心值
            ssc_int  <= Integer;
            ssc_frac <= Fraction;
            ssc_en   <= 1'b1;
        end else begin
            // SSC 模式: 正常扩频
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
