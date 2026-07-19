# FPGA Fractional-N PLL DTC 代码审查报告

**审查日期**: 2026-07-19  
**审查范围**: `FPGA_SSC_PLL.srcs/sources_1/new/` 及 `RTL/all/` 全部代码  
**核心问题**: DTC延迟最大仅100ps，目标8ns（80倍差距）

---

## 一、DTC延迟瓶颈深度分析

### 1.1 当前架构

`lut_dtc.v` 采用 **64级CARRY8级联 + 512:1 LUT MUX选择** 的方案：

```
din → CARRY8[0] → CARRY8[1] → ... → CARRY8[63] → tap[511]
                                                      ↓
                              tap[code] (512:1 MUX) → dout
```

- 每级CARRY8提供8个tap，共512个tap
- `assign dout = (code < N_TAP) ? tap[code] : tap[N_TAP-1];`
- 顶层 `fpga_ssc_pll_top.v` 级联了5个 `lut_dtc`

### 1.2 延迟瓶颈根因

| 延迟来源 | 理论值 | 实测值 | 问题 |
|----------|--------|--------|------|
| CARRY8进位链 (512 taps) | ~7.7ns (15ps/tap) | ~100ps | **MUX树延迟淹没了进位延迟** |
| tap[code] 512:1选择MUX | 3-5ns | 3-5ns | 9层LUT树，随code非线性 |
| 5级lut_dtc级联BUFG | ~2.5ns | ~2.5ns | 固定延迟，不可控 |

**根本原因**：`tap[code]` 这一行代码 `assign dout = tap[code]` 综合出来的512:1 MUX是一棵9层LUT树。这棵MUX树的延迟（3-5ns）远大于CARRY8进位链本身的延迟差（各tap之间仅差15ps）。结果就是：

- **code=0 和 code=511 的延迟差** ≈ 100ps（仅反映CARRY8进位差）
- **绝对延迟** ≈ 3-5ns（被MUX树主导，且固定）

更糟糕的是，Vivado无法将512个CARRY8 tap全部布局在同一个CLB列内。UltraScale+单列约24个Slice，只能容纳24个CARRY8（192 taps），剩余需要跨列布线，跨列布线延迟进一步打散了CARRY8的连续性。

### 1.3 目标分析：8ns延迟需求

在小数分频PLL中，DTC需要补偿的延迟范围由以下公式决定：

```
T_DTC_max = T_vco_period × (1 - 1/N_integer)
```

如果VCO频率为125MHz（T=8ns），整数分频比N=2，则：
- T_DTC_max = 8ns × (1 - 1/2) = 4ns

如果需要覆盖完整的8ns周期（即一个VCO周期），则DTC延迟范围必须达到8ns。

**当前100ps的延迟范围完全无法满足需求。**

### 1.4 解决方案

#### 方案A（推荐）：IDELAYE3 +级联（UltraScale+原生资源）

UltraScale+的IDELAYE3提供每tap约2.5-15ps的精确延迟（取决于DELAY_FORMAT），最大256 taps。

```verilog
// 单个IDELAYE3: 256 taps x ~15ps = ~3.84ns (TIME模式)
// 级联3个IDELAYE3 = ~11.5ns，覆盖8ns目标

module dtc_idelay #(
    parameter N_STAGE = 3,      // 级联级数
    parameter DELAY_WIDTH = 9   // 9-bit code = 512 taps
)(
    input  wire              din,
    input  wire [DELAY_WIDTH-1:0] code,
    input  wire              rst_n,
    input  wire              ref_clk,
    output wire              dout
);
    wire [N_STAGE:0] chain;

    assign chain[0] = din;

    genvar i;
    generate
        for (i = 0; i < N_STAGE; i = i + 1) begin : idelay_chain
            IDELAYE3 #(
                .DELAY_SRC         ("DATA"),       // DATA input
                .CASCADE           ("NONE"),       // No cascade for single
                .DELAY_FORMAT      ("TIME"),       // Time mode
                .DELAY_TYPE        ("VAR_LOAD"),   // Variable loadable
                .DELAY_VALUE       (0),            // Initial delay (taps)
                .REFCLK_FREQUENCY  (300.0),        // Reference clock freq
                .SIM_DEVICE        ("ULTRASCALE_PLUS")
            ) u_idelay (
                .CLK               (ref_clk),
                .LOAD              (1'b1),          // Load on every code change
                .CNTVALUEIN        (code[8:1]),     // 8-bit per stage
                .INC               (1'b0),
                .DEC               (1'b0),
                .DATAIN            (chain[i]),      // Input from previous stage
                .DATAOUT           (chain[i+1]),    // Output to next stage
                .CNTVALUEOUT       (),
                .CASCDATAIN       (),
                .CASCDATAOUT      (),
                .CE                (1'b0),
                .RST               (~rst_n),
                .CASCIN           (1'b0),
                .CASCOUT          (),
                .CINVCTRL         (1'b0)
            );
        end
    endgenerate

    assign dout = chain[N_STAGE];
endmodule
```

**优点**：
- 每tap 2.5-15ps（TIME模式下约15ps/tap @300MHz ref）
- 256 taps/级，3级级联 = 768 taps ≈ 11.5ns
- 延迟精确、单调、线性
- Xilinx原生原语，Vivado完全支持
- 需要IDELAYCTRL参考时钟（300MHz）

**注意**：
- IDELAYE3需要300MHz参考时钟驱动IDELAYCTRL
- 信号经过IDELAYE3后变为ODELAY类型，需注意布线约束

#### 方案B：LUT延时级联（无IDELAYCTRL依赖）

利用LUT2-LUT6的传播延迟（约0.1-0.3ns/LUT）构建延时链：

```verilog
module dtc_lut_delay #(
    parameter N_TAP = 64,
    parameter CODE_WIDTH = 6
)(
    input  wire              din,
    input  wire [CODE_WIDTH-1:0] code,
    output wire              dout
);
    wire [N_TAP-1:0] tap;

    genvar i;
    generate
        for (i = 0; i < N_TAP; i = i + 1) begin : delay_chain
            if (i == 0)
                LUT2 #(.INIT(4'b0100)) u_lut (
                    .I0(din), .I1(1'b1), .O(tap[0])
                );
            else
                LUT2 #(.INIT(4'b0100)) u_lut (
                    .I0(tap[i-1]), .I1(1'b1), .O(tap[i])
                );
        end
    endgenerate

    assign dout = tap[code];
endmodule
```

**延迟估算**：
- 每级LUT2延迟约0.1-0.2ns（UltraScale+ -2速度等级）
- 64级 = 6.4-12.8ns，可覆盖8ns
- MUX选择仍需解决（用CODE_WIDTH=6，64:1 MUX = 6层LUT树）

**优点**：
- 不需要IDELAYCTRL
- 每级延迟更大（0.1-0.2ns vs CARRY8的15ps）
- 64 taps即可覆盖8ns

**缺点**：
- 延迟随PVT变化较大
- 需要校准
- MUX树仍有非线性问题（但比512:1好很多）

#### 方案C：混合方案（CARRY8粗调 + IDELAYE3精调）

```
din → [CARRY8 x 64: 粗调, 0-960ps, 15ps/step]
       → [IDELAYE3 x 3: 精调+大范围, 0-11.5ns, 15ps/step]
       → dout
```

利用CARRY8提供细分辨率，IDELAYE3提供大范围。

### 1.5 5级lut_dtc级联的问题

`fpga_ssc_pll_top.v` 中级联了5个 `lut_dtc`（u_lut_dtc_0 到 u_lut_dtc_4），但**所有5级使用相同的 `dtc_code`**：

```verilog
lut_dtc u_lut_dtc_0 (... .code(dtc_code) ...);
lut_dtc u_lut_dtc_1 (... .code(dtc_code) ...);  // 相同code!
lut_dtc u_lut_dtc_2 (... .code(dtc_code) ...);  // 相同code!
lut_dtc u_lut_dtc_3 (... .code(dtc_code) ...);  // 相同code!
lut_dtc u_lut_dtc_4 (... .code(dtc_code) ...);  // 相同code!
```

**问题**：
1. 5级使用相同code，每级选择相同tap，延迟无法累加
2. 每级延迟固定 = MUX树延迟（3-5ns），5级 = 15-25ns固定延迟
3. 这解释了为什么实测只有100ps可变延迟——5级的CARRY8延迟差被各自的MUX树延迟淹没
4. 正确做法应该是：**用1个lut_dtc但增加tap数量**，或**每级使用不同的code分段控制**

---

## 二、其他代码显著问题

### 2.1 [严重] dtc_comp.v: dtc_load 始终为X

**文件**: `dtc_comp.v` 第15行、第35行

```verilog
output reg dtc_load   // 声明为reg
...
assign dtc_code = dtc_code_man_en ? dtc_code_man : code_sat;  // dtc_load从未赋值
```

**问题**: `dtc_load` 声明为 `output reg`，但所有赋值逻辑被注释掉（第37-48行），`dtc_load` 永远是X（未初始化）或0（综合后）。顶层 `fpga_ssc_pll_top.v` 将 `dtc_load` 连接到ILA观测和逻辑中，但实际无任何驱动。

**影响**: ILA中观察到的 `dtc_load` 信号无意义；如果后续逻辑依赖 `dtc_load`，会导致功能错误。

**修复**: 如果不需要 `dtc_load` 信号，应删除该端口；如果需要，应取消注释时序逻辑或直接 `assign dtc_load = dtc_en;`。

### 2.2 [严重] dtc_comp.v: 乘法位宽溢出

**文件**: `dtc_comp.v` 第28行

```verilog
wire [18:0] mult = e1 * 2'd2 * dtc_gain;
```

**问题**:
- `e1` 是 `[WIDTH-1:0]` = `[9:0]`（10位），但代码注释说"e1(8bit)"
- `e1 * 2'd2 * dtc_gain` = 10位 × 2位 × 8位 = 最大需要20位
- `mult` 声明为19位，可能溢出

**实际路径**: `e1` 来自 `mash_e1[9:0]`（fractionaln输出），最大值1023。`1023 * 2 * 255 = 521730`，需要20位（2^19 = 524288，刚好不溢出，但边界极险）。

**修复**: 将 `mult` 声明为 `[20:0]`，并确认 `e1` 实际位宽与WIDTH参数匹配。

### 2.3 [严重] dtc_comp.v: 饱和逻辑位宽不匹配

**文件**: `dtc_comp.v` 第31-32行

```verilog
wire [DTC_WIDTH-1:0] code_raw = mult[18:10] + dtc_offset;  // 9位 = 9位 + 9位
wire [DTC_WIDTH-1:0] code_sat = (code_raw > 9'd511) ? 9'd511 : code_raw;
```

**问题**:
1. `mult[18:10]` 是9位，`dtc_offset` 是9位，相加结果最多10位，赋值给9位的 `code_raw` 会截断高位
2. 饱和判断 `code_raw > 9'd511` 在截断后永远为假（9位最大值就是511），饱和逻辑失效
3. 应该先用10位做加法，再判断饱和

**修复**:
```verilog
wire [9:0] code_sum = mult[18:10] + dtc_offset;  // 10位加法
wire [DTC_WIDTH-1:0] code_sat = (code_sum > 10'd511) ? 9'd511 : code_sum[8:0];
```

### 2.4 [严重] dtc_comp.v: dtc_en 未使用

**文件**: `dtc_comp.v` 第12行

`dtc_en` 输入端口声明但从未在代码中使用（所有使用 `dtc_en` 的逻辑被注释）。这意味着DTC始终处于使能状态，无法通过VIO控制关闭。

### 2.5 [严重] fractionaln.v: Eo采样时钟域问题

**文件**: `fractionaln.v` 第32-38行

```verilog
always @(negedge Fout or negedge rst_n) begin
    if (!rst_n) begin
        Eo <= 10'd0;
    end else begin
        Eo <= Eo_d1;  // Eo_d1来自calculate_ps(posedge ~clk_delta_sigma)
    end
end
```

**问题**:
- `Eo` 在 `negedge Fout` 采样，但 `Eo_d1` 来自 `calculate_ps`，后者在 `posedge ~clk_delta_sigma`（即 `posedge ~Fout` = `negedge Fout`）更新
- 这意味着 `Eo` 和 `Eo_d1` 在同一个时钟沿更新，存在竞争
- `Eo_d1` 在 `negedge Fout` 更新，`Eo` 也在 `negedge Fout` 采样——`Eo` 拿到的是 `Eo_d1` 的**旧值**还是**新值**取决于综合器的时序分析

**影响**: 可能导致Eo延迟一个周期，影响DTC补偿的时序对齐。

**修复**: 明确使用寄存器级联，在 `posedge Fout` 采样 `Eo_d1`，确保跨沿安全。

### 2.6 [严重] calculate_ps.v: rst_n复位时加载Integer而非0

**文件**: `calculate_ps.v` 第27-28行

```verilog
if (!rst_n) begin
    real_integer <= Integer;  // 复位时加载Integer，不是0
    Eo <= 0;
```

**问题**: 复位时 `real_integer` 加载 `Integer` 的当前值。如果复位期间 `Integer` 不稳定（来自VIO），可能导致分频器以错误分频比启动。应复位为安全默认值。

### 2.7 [严重] calculate_ps.v: Pi截取方式与注释不符

**文件**: `calculate_ps.v` 第38-39行

```verilog
//assign Pi = real_integer[INT_WIDTH-1:INT_WIDTH-P_WIDTH];  // 被注释
assign Pi = real_integer >> 2;  // 实际使用
assign Si = real_integer[S_WIDTH-1:0];
```

**问题**:
- 注释的版本取高6位，实际版本取 `>> 2`（即 `[INT_WIDTH-1:2]` 的低6位）
- `Pi` 是6位（P_WIDTH=6），`real_integer >> 2` 会产生8位结果，截取低6位
- 这两种方式在整数分频比 ≤ 255 时结果不同
- `Pi` 和 `Si` 应该共同表示 `real_integer`，但 `Pi = >> 2` 和 `Si = [1:0]` 的组合可能不连续

**影响**: 分频比计算错误，导致输出频率错误。

**修复**: 明确Pi/Si的拆分逻辑。如果是4/5双模分频器，Pi应该是高6位，Si应该是低2位：
```verilog
assign Pi = real_integer[INT_WIDTH-1:INT_WIDTH-P_WIDTH];
assign Si = real_integer[S_WIDTH-1:0];
```

### 2.8 [严重] mash111.v: eo_d1复位值错误

**文件**: `mash111.v` 第74行

```verilog
if (!rst_n) begin
    eo_d1 <= 1'b0;  // 应为WIDTH位宽的0
    y_o <= 4'b0;
```

**问题**: `eo_d1` 声明为 `reg [WIDTH-1:0]`（10位），但复位值 `1'b0` 只有1位。虽然Verilog会自动零扩展，但这是不规范的写法，可能引起综合警告。

**修复**: `eo_d1 <= {WIDTH{1'b0}};` 或 `eo_d1 <= 'b0;`

### 2.9 [严重] mash111.v: stage_sel来自VIO但无默认值

**文件**: `mash111.v` 第122-125行

```verilog
mash_stage u_mash_stage (
    .clk (clk),
    .probe_out0 (stage_sel)
);
```

**问题**: `stage_sel` 由VIO控制，但 `y_o` 的输出完全依赖 `stage_sel`：
```verilog
y_o <= (stage_sel == 2'b00) ? c2 :
       (stage_sel == 2'b01) ? y_o_1 :
       (stage_sel == 2'b10) ? y_o_1 + y_o_2 - y2_d : 
                              y_o_1 + y_o_2 - y2_d + (y_o_3 - y3_d - y3_d + y3_dd);
```

如果VIO未配置或 `stage_sel` 为X，`y_o` 输出X，导致整个分频链异常。

### 2.10 [中等] dff.v: 异步LD与同步rst_n混合

**文件**: `dff.v` 第13行

```verilog
always @(posedge clk or negedge rst_n or posedge LD) begin
```

**问题**: `rst_n` 是异步低复位，`LD` 是异步高置位。两者同时有效时（rst_n=0, LD=1），代码优先处理 `~rst_n` 分支，Q=0。但如果 `LD` 在 `rst_n` 释放前沿到来，可能产生竞争。

**影响**: 在高频（625MHz）下，LD的异步路径可能导致建立/保持时间违例。

### 2.11 [中等] reg_async.v: 完全无用的模块

**文件**: `reg_async.v` 第14-15行

```verilog
always @(posedge clk) begin
    Q <= Q;  // 自赋值，永远保持原值
end
```

**问题**: `Q <= Q` 是自引用，寄存器永远保持复位后的初始值（未初始化则X）。D输入完全被忽略。这个模块功能上是一个"永不变化的寄存器"。

**影响**: 如果任何地方实例化了 `reg_async`，该寄存器输出恒定，可能导致功能错误。当前代码中未见实例化，但应删除或修复。

### 2.12 [中等] p_counter.v: Fout实际不是寄存器输出

**文件**: `p_counter.v` 第66行

```verilog
assign Fout = ld_q; //qn_o[Pi_correct] & qn_o[Pi_correct-1];
```

**问题**: 注释说"修复: Fout 由组合逻辑改为寄存器输出"，但 `ld_q` 来自 `u_ld_dff`，而 `dff.v` 的 `ld_d` 输入是组合逻辑：
```verilog
assign ld_d = ~(qn_o[0]|h_nand);
```

所以 `ld_q` 是 `ld_d` 寄存一拍的结果——确实是寄存器输出，但寄存器的内容是基于组合逻辑的。注释描述的修复是有效的（消除了Pi变化时的组合毛刺），但注释描述"组合逻辑改为寄存器输出"的表述不够准确。

### 2.13 [中等] s_counter.v: d_i[0]使能逻辑可能有问题

**文件**: `s_counter.v` 第72行

```verilog
assign d_i[0] = h_and ? q_o[0] : qn_o[0];  // h_and=1时保持
```

**问题**: 当 `h_and=1`（所有位为1）时，`d_i[0] = q_o[0]`，即D输入等于当前Q输出，FF保持不变。当 `h_and=0` 时，`d_i[0] = qn_o[0]`，即翻转。

但 `h_and = &qn_o`，是组合逻辑。如果 `qn_o` 在时钟边沿附近变化，`d_i[0]` 的选择器可能产生毛刺。虽然FF的D输入在CLK边沿采样，但如果 `h_and` 的变化恰好在建立/保持窗口内，可能产生亚稳态。

### 2.14 [中等] fpga_ssc_pll_top.v: rst_n_dtc门控不完整

**文件**: `fpga_ssc_pll_top.v` 第71行

```verilog
assign and_rst_n_dtc = 1'b1 && sys_rst_n;
```

**问题**: `and_rst_n_dtc` 只受 `sys_rst_n` 控制，不像 `and_rst_n_fracn` 那样门控 `locked_pll`。DTC在PLL未锁定时就开始工作，但此时输入信号 `div_out_raw` 可能不稳定。

### 2.15 [中等] fpga_ssc_pll_top.v: div_out_dtc未在DTC未使用时旁路

DTC链（5级lut_dtc）始终连接在 `div_out_raw_g` 和 `div_out_dtc` 之间。如果DTC功能未启用（dtc_en=0），信号仍需穿过5级lut_dtc的MUX树，引入约15-25ns的固定延迟。

**修复**: 添加BUFGMUX旁路路径，当 `dtc_en=0` 时选择 `div_out_raw_g` 直通。

### 2.16 [低] div_89.v: 存在但未使用

`div_89.v` 定义了8/9分频器，但当前设计中 `dual_div.v` 使用 `div_45`（4/5分频）。`div_89.v` 是冗余文件。

### 2.17 [低] div_2.v: 模块名与文件名不一致

文件名为 `div_2.v`，但模块名为 `div2`（无下划线）。虽然Verilog允许，但不规范。

### 2.18 [低] efm.v: 与hk_efm.v功能重复

`efm.v` 是基本EFM，`hk_efm.v` 是Horschler-Kenny EFM。`mash111.v` 使用 `hk_efm`，`efm.v` 未被使用。应删除冗余文件。

---

## 三、问题优先级汇总

| # | 文件 | 严重度 | 问题 |
|---|------|--------|------|
| 1 | lut_dtc.v | **致命** | CARRY8延迟链被MUX树淹没，100ps vs 8ns目标 |
| 2 | fpga_ssc_pll_top.v | **致命** | 5级lut_dtc使用相同code，延迟无法累加 |
| 3 | dtc_comp.v | 严重 | dtc_load从未赋值，永远为X |
| 4 | dtc_comp.v | 严重 | 乘法位宽可能溢出（19位存20位结果） |
| 5 | dtc_comp.v | 严重 | 饱和逻辑截断后失效 |
| 6 | dtc_comp.v | 严重 | dtc_en未使用 |
| 7 | fractionaln.v | 严重 | Eo采样时钟域竞争 |
| 8 | calculate_ps.v | 严重 | 复位时加载Integer非0 |
| 9 | calculate_ps.v | 严重 | Pi截取方式可能与设计意图不符 |
| 10 | mash111.v | 严重 | stage_sel来自VIO无默认值 |
| 11 | dff.v | 中等 | 异步LD与rst_n混合竞争 |
| 12 | reg_async.v | 中等 | Q<=Q自赋值，模块无功能 |
| 13 | s_counter.v | 中等 | h_and组合逻辑可能产生亚稳态 |
| 14 | fpga_ssc_pll_top.v | 中等 | rst_n_dtc未门控locked_pll |
| 15 | fpga_ssc_pll_top.v | 中等 | DTC无旁路路径 |
| 16 | div_89.v | 低 | 冗余文件 |
| 17 | div_2.v | 低 | 模块名与文件名不一致 |
| 18 | efm.v | 低 | 与hk_efm.v重复 |

---

## 四、DTC 8ns方案推荐

### 最终推荐：方案A（IDELAYE3级联）

理由：
1. IDELAYE3是UltraScale+原生资源，每tap延迟精确（~15ps @300MHz ref）
2. 3级IDELAYE3级联 = 768 taps ≈ 11.5ns，覆盖8ns
3. 延迟单调线性，无需复杂的MUX选择树
4. Vivado原生支持，时序约束完善
5. 需要额外提供300MHz参考时钟（可从MMCM分频输出）

### 替代方案：方案B（LUT延时级联）

如果无法提供300MHz参考时钟：
1. 64级LUT2延时链，每级0.1-0.2ns
2. 64:1 MUX选择（6层LUT树，延迟约1-2ns）
3. 总延迟范围：6.4-12.8ns，可覆盖8ns
4. 需要上电校准（TDC自校准测量实际延迟）

### 关键修改点

1. **删除5级lut_dtc级联**，改为单级DTC模块
2. **删除tap[code]的MUX选择**，改为IDELAYE3的CNTVALUEIN直接控制
3. **dtc_comp.v输出code改为直接给IDELAYE3的CNTVALUEIN**
4. **添加300MHz参考时钟生成**（从MMCM分频）
5. **添加IDELAYCTRL实例**

---

## 五、附录：代码修改清单

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `lut_dtc.v` | 重写 | 改用IDELAYE3级联方案 |
| `fpga_ssc_pll_top.v` | 修改 | 删除5级级联，改为单级DTC；添加IDELAYCTRL |
| `dtc_comp.v` | 修改 | 修复dtc_load、位宽、饱和逻辑、dtc_en |
| `fractionaln.v` | 修改 | 修复Eo采样时钟域 |
| `calculate_ps.v` | 修改 | 修复Pi截取、复位值 |
| `mash111.v` | 修改 | 修复stage_sel默认值、eo_d1复位 |
| `reg_async.v` | 删除 | 无功能模块 |
| `efm.v` | 删除 | 冗余文件 |
| `div_89.v` | 删除 | 未使用 |
