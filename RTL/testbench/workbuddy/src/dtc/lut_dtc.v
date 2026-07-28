`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// CARRY8-based lut_dtc for functional simulation
//
// 主延迟路径: 64 个 CARRY8 级联链 + 3 层分级 MUX (512 tap)
// 校准路径:  行为模型 TDC (16 级链, vco_clk 域计数)
//
// 注意: CARRY8 模型为零延迟 (iverilog v12 带 #delay 的 64 实例会崩溃)
//       如需真实延迟, 需用 Vivado 仿真或后仿 SDF
////////////////////////////////////////////////////////////////////////////////

module lut_dtc #(
    parameter N_TAP = 512,
    parameter CODE_WIDTH = 9
)(
    input  wire                  sys_clk,
    input  wire                  rst_n,
    input  wire                  din,
    input  wire [CODE_WIDTH-1:0] code,
    input  wire                  cal_mode,
    input  wire                  dtc_sel,
    output wire                  dout,
    output reg  [CODE_WIDTH-1:0] cal_result,
    output reg                   cal_valid
);

    localparam N_CARRY   = N_TAP / 8;           // 64
    localparam N_GROUP   = 8;                    // 8 个 group
    localparam N_CAR_PER = N_CARRY / N_GROUP;    // 8 个 CARRY8 每 group

    // ---- CARRY8 的 CO 输出 ----
    wire [7:0] co [0:N_CARRY-1];

    // ---- CARRY8 级联链 ----
    // Level 0: 信号从 din 进入 CI
    CARRY8 #(
        .CARRY_TYPE("SINGLE_CY8")
    ) u_carry_0 (
        .CO     (co[0]),
        .O      (),
        .CI     (din),
        .CI_TOP (1'b0),
        .DI     (8'b0),
        .S      (8'hFF)
    );

    // Level 1~63: co[i-1][7] -> CI
    genvar i;
    generate
        for (i = 1; i < N_CARRY; i = i + 1) begin : cascade
            CARRY8 #(
                .CARRY_TYPE("SINGLE_CY8")
            ) u_carry (
                .CO     (co[i]),
                .O      (),
                .CI     (co[i-1][7]),
                .CI_TOP (1'b0),
                .DI     (8'b0),
                .S      (8'hFF)
            );
        end
    endgenerate

    // ============================================================
    // 3 层分级 MUX: 512:1 -> 8x8x8 分层
    // 位域: code[8:6]=group, code[5:3]=CARRY8, code[2:0]=bit
    // ============================================================

    // Layer 1: 每个 CARRY8 内 8:1 bit MUX
    wire [N_CARRY-1:0] bit_sel;
    genvar c;
    generate
        for (c = 0; c < N_CARRY; c = c + 1) begin : bit_mux
            assign bit_sel[c] = co[c][code[2:0]];
        end
    endgenerate

    // Layer 2: 每个 group 内 8:1 CARRY8 MUX
    wire [N_GROUP-1:0] group_sel;
    genvar g;
    generate
        for (g = 0; g < N_GROUP; g = g + 1) begin : carry_mux
            wire [N_CAR_PER-1:0] group_bits;
            genvar k;
            for (k = 0; k < N_CAR_PER; k = k + 1) begin : group_map
                assign group_bits[k] = bit_sel[g * N_CAR_PER + k];
            end
            assign group_sel[g] = group_bits[code[5:3]];
        end
    endgenerate

    // Layer 3: 顶层 8:1 group MUX
    wire dout_raw;
    assign dout_raw = group_sel[code[8:6]];

    // ================================================================
    // Delay model: 40ps per tap (code-controlled variable delay)
    // CARRY8 chain above is zero-delay for iverilog stability;
    // real delay is modeled here via non-blocking transport delay.
    // ================================================================
    reg dout_r;
    always @(din or code) begin
        dout_r <= #(code * 0.004) din;
    end
    assign dout = dout_r;

    // ============================================================
    // TDC 行为模型 (vco_clk 域, 用于校准链)
    // 16 级 cascade 总延迟 = 16 * code * 40ps
    // VCO ~625MHz (1.6ns) -> cal_result = 16*code*40ps/1600ps = (code*2)/5
    // ============================================================
    reg [8:0] tdc_cnt  = 0;
    reg [8:0] tdc_code = 0;
    reg       tdc_busy = 0;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            cal_valid  <= 1'b0;
            cal_result <= 0;
            tdc_cnt    <= 0;
            tdc_code   <= 0;
            tdc_busy   <= 0;
        end else if (cal_mode && !tdc_busy) begin
            tdc_code   <= code;
            tdc_cnt    <= (code * 2) / 5;
            tdc_busy   <= 1;
            cal_valid  <= 1'b0;
        end else if (tdc_busy) begin
            if (tdc_cnt == 0) begin
                tdc_busy   <= 0;
                cal_valid  <= 1'b1;
                cal_result <= (tdc_code * 2) / 5;
            end else begin
                tdc_cnt    <= tdc_cnt - 1;
                cal_valid  <= 1'b0;
            end
        end else begin
            cal_valid <= 1'b0;
        end
    end

endmodule
