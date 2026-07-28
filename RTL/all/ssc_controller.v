`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// SSC (Spread Spectrum Clocking) 扩频时钟控制器
// 控制 fracn 小数分频比，实现中心扩频或向下扩频
//
// 功能:
//   spread_type=0 (center):  频率在中心值上下 ±spread_ppm 调制
//   spread_type=1 (down):    频率从中心值向下 spread_ppm 调制
//
// 手动控制:
//   spread_ppm: 展频范围 (ppm)，例如 5000 = 0.5%
//   spread_type: 0=中心展频, 1=向下展频
////////////////////////////////////////////////////////////////////////////////

module ssc_controller #(
    parameter MODULATION_FREQ = 30000,      // 调制频率 30kHz
    parameter FRAC_WIDTH      = 10,         // 小数位宽
    parameter INT_WIDTH       = 8           // 整数位宽
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        bypass,         // 1: bypass 模式
    input  wire                        spread_type,    // 0=center, 1=down
    input  wire [15:0]                 spread_ppm,     // 展频范围 (ppm)

    input  wire [INT_WIDTH-1:0]        Integer,        // 中心分频比整数部分
    input  wire [FRAC_WIDTH-1:0]       Fraction,       // 中心分频比小数部分

    output reg  [INT_WIDTH-1:0]        ssc_int,
    output reg  [FRAC_WIDTH-1:0]       ssc_frac,
    output reg                          ssc_en
);

    // ============================================================
    // 参数计算
    // ============================================================
    localparam MOD_PERIOD = 12500000 / MODULATION_FREQ;  // 416
    localparam MOD_CNT_WIDTH = $clog2(MOD_PERIOD);

    // ============================================================
    // 三角波调制生成器
    // ============================================================
    reg [MOD_CNT_WIDTH-1:0] mod_cnt;
    reg                     mod_dir;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mod_cnt <= {MOD_CNT_WIDTH{1'b0}};
            mod_dir <= 1'b0;
        end else if (!bypass) begin
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
            mod_cnt <= {MOD_CNT_WIDTH{1'b0}};
            mod_dir <= 1'b0;
        end
    end

    // ============================================================
    // MAX_OFFSET 计算: spread_ppm * (Integer * 2^FRAC + Fraction) / 1000000
    // 物理意义: spread_ppm 对应的小数步进值
    // ============================================================
    wire [INT_WIDTH+FRAC_WIDTH-1:0] total_ratio = (Integer << FRAC_WIDTH) + Fraction;
    wire [31:0]                     max_off_prod = spread_ppm * total_ratio;
    wire [15:0]                     max_offset = max_off_prod / 1000000;

    // ============================================================
    // 扩频偏移量计算
    // ============================================================
    wire [FRAC_WIDTH+MOD_CNT_WIDTH-1:0] offset_mult;

    // 三角波 → frac_offset 映射:
    //   center:  frac_offset = 2*mod_cnt*max/MOD - max   (-max ~ +max, 有符号)
    //   down:    frac_offset = mod_cnt*max/MOD - max      (-max ~ 0,  有符号, 真·下展频)
    assign offset_mult = mod_cnt * max_offset;

    wire [FRAC_WIDTH-1:0] frac_offset_raw = offset_mult / MOD_PERIOD;

    // Center-spread: 有符号偏移 -max ~ +max
    wire signed [FRAC_WIDTH:0] offset_2x  = $signed({1'b0, frac_offset_raw}) + $signed({1'b0, frac_offset_raw});
    wire signed [FRAC_WIDTH:0] offset_neg = offset_2x - $signed(max_offset);  // -max ~ +max

    // Down-spread: 反馈分频 f_vco=f_pfd*N_fb, 下展频需 N_fb<=标称 → 负偏移
    wire signed [FRAC_WIDTH:0] offset_down = $signed({1'b0, frac_offset_raw}) - $signed(max_offset);

    // 全程有符号, 否则负数回绕成大正数触发错误进位
    wire signed [FRAC_WIDTH:0] frac_off_comb = spread_type ? offset_down : offset_neg;

    // ============================================================
    // 分频比合成 (带 bypass)  -- 全程有符号
    // ============================================================
    // down:   frac_sum = Fraction + offset_down  (-max ~ 0,  VCO 向下)
    // center: frac_sum = Fraction + offset_neg   (-max ~ +max)
    wire signed [FRAC_WIDTH+1:0] frac_sum = $signed({1'b0, Fraction}) + $signed(frac_off_comb);

    wire                frac_carry  = (frac_sum >= (1 << FRAC_WIDTH));   // 正溢出 → Integer+1 (VCO 升)
    wire                frac_borrow = (frac_sum < 0);                    // 负溢出 → Integer-1 (VCO 降, 两模式都需要)

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ssc_int  <= Integer;
            ssc_frac <= Fraction;
            ssc_en   <= 1'b0;
        end else if (bypass) begin
            ssc_int  <= Integer;
            ssc_frac <= Fraction;
            ssc_en   <= 1'b1;
        end else begin
            ssc_en <= 1'b1;

            if (frac_carry) begin
                // 上溢出: Integer + 1
                ssc_int  <= Integer + 1'b1;
                ssc_frac <= frac_sum[FRAC_WIDTH-1:0];
            end else if (frac_borrow) begin
                // 下溢出 (center-spread 负半周): Integer - 1
                ssc_int  <= Integer - 1'b1;
                ssc_frac <= frac_sum[FRAC_WIDTH-1:0];
            end else begin
                ssc_int  <= Integer;
                ssc_frac <= frac_sum[FRAC_WIDTH-1:0];
            end
        end
    end

endmodule
