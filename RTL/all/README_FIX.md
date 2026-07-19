# FPGA Fractional-N PLL 毛刺修复 + DTC 优化

修复日期: 2026-07-17

## 修改文件清单

### fractional-N 分频器 (RTL/all/new/)

| 文件 | 状态 | 修改内容 |
|------|------|----------|
| `dual_div.v` | **修改** | 删除 ss_cnt/MC_dly 延迟链, MC 直连 div_45 (根因修复) |
| `p_counter.v` | **修改** | Fout 组合逻辑→寄存器输出, 消除 Pi 变化时的组合毛刺 |
| `s_counter.v` | **修改** | 门控时钟 clk_i[0] 改为 Fin 纯时钟 + d_i[0] 使能 |
| `fpga_ssc_pll_top.v` | **修改** | and_rst_n_fracn 门控 locked_pll, 修正 div_cnt_cmp→ref_div_cnt_cmp |
| 其余 12 个 .v | 不变 | 从原目录复制 |

### DTC 延迟线 (FPGA_SSC_PLL/.../new/fixed/)

| 文件 | 状态 | 修改内容 |
|------|------|----------|
| `lut_dtc.v` | **修改** | 3层分级MUX替换512:1扁平MUX; 增加cal_mode功能 |
| `debug_clk.v` | 不变 | 复制 |
| `en_buf.v` | 不变 | 复制 |

## 毛刺根因总结

```
MC_dly 自由计数器 +1 cycle delay → div_45 模数切换错位
    ↓ (叠加)
Pi 变化时 p_counter.Fout 组合毛刺 → Fout_reg(Fin=625MHz) 捕获
    ↓
示波器输出周期突变 (毛刺)
```

## DTC 优化要点

- **原问题**: 512:1扁平MUX ≈ 9层LUT, 延迟3-5ns且随code变化, 淹没了CARRY8微细延迟
- **修复**: code[8:6]group + code[5:3]CARRY8 + code[2:0]bit → 3层LUT MUX ≈1.5ns
- **效果**: MUX延迟更小更线性, CARRY8的微细延迟(10-15ps/tap)可以被有效利用

## 如何使用

将 new/ 目录下的文件替换到项目中对应的源文件目录:
- RTL: `RTL/all/new/*.v` → 替换原 `RTL/all/` 和 `RTL/all/fracn_div/` 下对应文件
- DTC: `.../new/fixed/lut_dtc.v` → 替换原版本
