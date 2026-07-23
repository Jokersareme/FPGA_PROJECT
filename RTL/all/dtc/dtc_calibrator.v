`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: dtc_calibrator
//
// 校准流程 (每次测量排空1次, 取第2次):
//   1. cal_mode_ext ↑ 触发
//   2. dtc_code=0, cal_mode=1 → 等 cal_valid (第1次→丢弃)
//   3. cal_mode=0→1 (复位TDC) → 等 cal_valid (第2次→存 tdc_min)
//   4. dtc_code=511, 同上二次测量 → 存 tdc_max
//   5. dtc_gain = K / (tdc_max - tdc_min)
//   K = (2^SHIFT × 16 × MAX_CODE / 2^FRAC_WIDTH) / N_STAGES
//     order_sel=0: N_STAGES=1, 1级链, K = K_BASE
//     order_sel=1: N_STAGES=4, 4级链, K = K_BASE / 4
////////////////////////////////////////////////////////////////////////////////

module dtc_calibrator #(
    parameter FRAC_WIDTH = 10,
    parameter CODE_WIDTH = 9,
    parameter GAIN_WIDTH = 10,
    parameter TDC_WIDTH  = 9,
    parameter MAX_CODE   = 511,
    parameter SHIFT      = 11
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                cal_mode_ext,
    input  wire                order_sel,      // 0=1阶(K=K_BASE), 1=3阶(K=K_BASE/4)
    output reg                 cal_mode,
    input  wire [TDC_WIDTH-1:0] cal_result,
    input  wire                cal_valid,
    output reg [CODE_WIDTH-1:0] dtc_code_cal,
    output reg [GAIN_WIDTH-1:0] dtc_gain_cal,
    output reg                 cal_done,
    output reg [TDC_WIDTH-1:0] tdc_min,
    output reg [TDC_WIDTH-1:0] tdc_max
);

    localparam K_BASE = ((1 << SHIFT) * 16 * MAX_CODE) >> FRAC_WIDTH;  // 15-bit max
    wire [14:0] K_CONST = order_sel ? K_BASE >> 2  : K_BASE;

    localparam [3:0]
        S_IDLE        = 4'd0,
        SM_MIN_CODE   = 4'd1,
        SM_MIN_DISCARD= 4'd2,
        SM_MIN_FLUSH  = 4'd3,
        SM_MIN_MEAS   = 4'd4,
        SM_MIN_STORE  = 4'd5,
        SM_MAX_CODE   = 4'd6,
        SM_MAX_DISCARD= 4'd7,
        SM_MAX_FLUSH  = 4'd8,
        SM_MAX_MEAS   = 4'd9,
        SM_MAX_STORE  = 4'd10,
        SM_DIVIDE     = 4'd11,
        SM_SATURATE   = 4'd12,
        SM_DONE       = 4'd13;

    reg [3:0] state, next;
    reg ce_d1;
    wire ce_rise;
    reg [15:0] wait_cnt;

    // 除法器 (15-bit ÷ 10-bit = 10-bit)
    reg [14:0] dividend;
    reg [9:0]  divisor;
    reg [14:0] quotient;   // 15-bit 商（15 次迭代）
    reg [14:0] remainder;
    reg [3:0]  div_cnt;
    reg        div_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ce_d1 <= 1'b0;
        else        ce_d1 <= cal_mode_ext;
    end
    assign ce_rise = cal_mode_ext && !ce_d1;

    // ====================================================================
    // 次态逻辑
    // ====================================================================
    always @(*) begin
        next = state;
        // cal_mode_ext=0 时强制复位状态机 (任何时候终止校准)
        if (state != S_IDLE && !cal_mode_ext) begin
            next = S_IDLE;
        end else begin
        case (state)
            S_IDLE:         if (ce_rise) next = SM_MIN_CODE;
            SM_MIN_CODE:    next = SM_MIN_DISCARD;
            SM_MIN_DISCARD: if (cal_valid || wait_cnt == 16'hFFFF) next = SM_MIN_FLUSH;
            SM_MIN_FLUSH:   next = SM_MIN_MEAS;
            SM_MIN_MEAS:    if (cal_valid || wait_cnt == 16'hFFFF) next = SM_MIN_STORE;
            SM_MIN_STORE:   next = SM_MAX_CODE;
            SM_MAX_CODE:    next = SM_MAX_DISCARD;
            SM_MAX_DISCARD: if (cal_valid || wait_cnt == 16'hFFFF) next = SM_MAX_FLUSH;
            SM_MAX_FLUSH:   next = SM_MAX_MEAS;
            SM_MAX_MEAS:    if (cal_valid || wait_cnt == 16'hFFFF) next = SM_MAX_STORE;
            SM_MAX_STORE:
                if (tdc_max > tdc_min) next = SM_DIVIDE;
                else                   next = SM_SATURATE;
            // 注意: action 用 case(next) 驱动
            // 当 div_cnt>=10 时如果 next=SM_DONE, finish 块不会被触发
            // 正确时序: div_cnt=10 → 在 SM_DIVIDE 里执行 finish → div_busy=0 → 下一拍进 SM_DONE
            SM_DIVIDE:      if (div_busy && div_cnt >= 4'd10) next = SM_DIVIDE;  // 先留下跑 finish
                            else if (!div_busy)               next = SM_DONE;    // finish 已完成, 走
                            else                              next = SM_DIVIDE;
            SM_SATURATE:    next = SM_DONE;
            SM_DONE:        next = S_IDLE;
        endcase
        end
    end

    // ====================================================================
    // 动作逻辑
    // ====================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; cal_mode <= 1'b0; dtc_code_cal <= 0;
            tdc_min <= 0; tdc_max <= 0; dtc_gain_cal <= 0;
            cal_done <= 1'b0; wait_cnt <= 0;
            dividend <= 0; divisor <= 0; quotient <= 0;
            remainder <= 0; div_cnt <= 0; div_busy <= 1'b0;
        end else begin
            state <= next;
            cal_done <= 1'b0;

            case (next)
                S_IDLE: begin
                    cal_mode <= 1'b0; wait_cnt <= 0; div_busy <= 1'b0;
                end

                SM_MIN_CODE: begin
                    cal_mode <= 1'b1; dtc_code_cal <= 0; wait_cnt <= 0;
                end
                SM_MIN_DISCARD: wait_cnt <= wait_cnt + 1;
                SM_MIN_FLUSH: begin
                    cal_mode <= 1'b0; wait_cnt <= 0;
                end
                SM_MIN_MEAS: begin
                    cal_mode <= 1'b1; wait_cnt <= wait_cnt + 1'b1;
                end
                SM_MIN_STORE: begin
                    tdc_min <= cal_result; cal_mode <= 1'b0; wait_cnt <= 0;
                end

                SM_MAX_CODE: begin
                    cal_mode <= 1'b1; dtc_code_cal <= MAX_CODE[CODE_WIDTH-1:0]; wait_cnt <= 0;
                end
                SM_MAX_DISCARD: wait_cnt <= wait_cnt + 1;
                SM_MAX_FLUSH: begin
                    cal_mode <= 1'b0; wait_cnt <= 0;
                end
                SM_MAX_MEAS: begin
                    cal_mode <= 1'b1; wait_cnt <= wait_cnt + 1'b1;
                end
                SM_MAX_STORE: begin
                    tdc_max <= cal_result; cal_mode <= 1'b0; wait_cnt <= 0;
                end

                SM_DIVIDE: begin
                    if (!div_busy) begin
                        dividend  <= K_CONST;
                        divisor   <= {1'b0, tdc_max - tdc_min};  // 10-bit
                        quotient  <= 0; remainder <= 0;
                        div_cnt   <= 0; div_busy <= 1'b1;
                    end else if (div_cnt < 4'd15) begin   // 15 次迭代
                        // 用 15-bit 完整移位后余数比较和减法
                        if ({remainder[13:0], dividend[14]} >= {5'b0, divisor}) begin
                            quotient[14 - div_cnt] <= 1'b1;
                            remainder <= {remainder[13:0], dividend[14]} - {5'b0, divisor};
                        end else begin
                            quotient[14 - div_cnt] <= 1'b0;
                            remainder <= {remainder[13:0], dividend[14]};
                        end
                        dividend <= {dividend[13:0], 1'b0};
                        div_cnt  <= div_cnt + 1'b1;
                    end else begin
                        div_busy <= 1'b0;
                        // 15-bit 商截低 10 bit 给 gain
                        dtc_gain_cal <= (quotient[9:0] > 10'd1023) ? 10'd1023 : quotient[9:0];
                    end
                end

                SM_SATURATE: dtc_gain_cal <= {GAIN_WIDTH{1'b1}};
                SM_DONE:     cal_done <= 1'b1;
            endcase
        end
    end

endmodule
