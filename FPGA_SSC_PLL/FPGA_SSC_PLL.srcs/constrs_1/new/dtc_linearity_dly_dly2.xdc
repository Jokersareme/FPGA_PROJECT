# ============================================================================
# DTC 线性度约束 —— 仅作用于 u_lut_dtc_dly 与 u_lut_dtc_dly2
#
# 设计意图:
#   - 把这两个延迟链实例内部的 64 级 CARRY8 锁成各自一条竖直单列;
#   - 把各自模块内的 3 层分级 MUX (bit_mux / carry_mux / group_sel) 也收进
#     同一 pblock (CARRY8 列 + 右侧一列给 MUX 走线);
#   - 使相邻 tap 物理间距一致、group 边界路由对称, 从而改善 DNL / INL。
#
# 作用范围 (精确命中, 不影响其它实例):
#   *lut_dtc_top/u_lut_dtc_dly/*   —— 主链 stage 1
#   *lut_dtc_top/u_lut_dtc_dly2/*  —— 主链 stage 2
#   u_lut_dtc_dly3 / u_lut_dtc_dly4 / 校准 cascade 均不被本文件约束。
#
# ⚠️ 使用前必须修改 (见文件底部 BASE_* 变量):
#   1. 用 Vivado Device 视图挑两条靠近芯片中部、且互不重叠的 SLICE 列
#      (XCVU9P 一个 CLOCK_REGION 约 60 SLICE 高, 单列需 >=64 高)。
#   2. 两个链必须放在不同列 (BASE_X_DLY != BASE_X_DLY2), 否则会争抢
#      同一条 CARRY8 级联列导致布局失败。
#   3. 本文件为独立约束, 需在 Vivado 中将其加入约束集 (Add Sources ->
#      Constraints), 或 `read_xdc dtc_linearity_dly_dly2.xdc`。
# ============================================================================

# ---------- 1. 取出两个实例内全部 CARRY8 ----------
set carry_dly  [get_cells -hierarchical -filter {NAME =~ *lut_dtc_top/u_lut_dtc_dly/*u_carry*}]
set carry_dly2 [get_cells -hierarchical -filter {NAME =~ *lut_dtc_top/u_lut_dtc_dly2/*u_carry*}]

if {[llength $carry_dly] == 0}  { puts "WARNING: 未匹配到 u_lut_dtc_dly 的 CARRY8, 请检查层次名" }
if {[llength $carry_dly2] == 0} { puts "WARNING: 未匹配到 u_lut_dtc_dly2 的 CARRY8, 请检查层次名" }

# ---------- 2. 按级联顺序对 CARRY8 赋 RLOC (竖直单列, Y 递增) ----------
# 级联顺序: u_carry_0, cascade[1].u_carry, ..., cascade[63].u_carry
# RLOC 采用 "R<y>C<x>": y 递增 = 沿 SLICE 列向下堆叠 (CARRY8 竖向级联)。
proc place_carry_chain {cells base_x base_y} {
    set c0   {}
    set rest {}
    foreach c $cells {
        if {[string match "*u_carry_0" $c]} {
            lappend c0 $c
        } elseif {[regexp {cascade\[(\d+)\]\.u_carry} $c -> idx]} {
            lappend rest [list $idx $c]
        }
    }
    set rest   [lsort -integer -index 0 $rest]
    set ordered [concat $c0 [lmap p $rest {lindex $p 1}]]
    set i 0
    foreach c $ordered {
        set_property RLOC [format "R%dC%d" [expr {$base_y + $i}] $base_x] $c
        set_property BEL  CARRY8 $c
        incr i
    }
    puts "INFO: 已为 [llength $ordered] 个 CARRY8 赋 RLOC (base_x=$base_x base_y=$base_y)"
}

# ---------- 3. Pblock: 单列 CARRY8 + 右侧一列给 MUX (2 列宽, 够高) ----------
proc make_dtc_pblock {pname inst_glob base_x base_y height} {
    create_pblock $pname
    add_cells_to_pblock $pname [get_cells -hierarchical -filter "NAME =~ $inst_glob"]
    # 2 列宽 (左列放 CARRY8, 右列放 MUX), height 行高
    resize_pblock $pname -add \
        SLICE_X${base_x}Y${base_y}:SLICE_X[expr {$base_x + 1}]Y[expr {$base_y + $height}]
    set_property CONTAIN_ROUTING true [get_pblocks $pname]
    set_property SNAPPING_MODE    ON   [get_pblocks $pname]
    set_property PBlock_Min_Height 64  [get_pblocks $pname]
}

# ============================================================================
# ⚠️ 占位坐标 —— 必须替换为目标芯片真实 SLICE 坐标!
#    例: 若选 SLICE_X40Y100 所在列, 则 base_x=40 base_y=100
# ============================================================================
set BASE_X_DLY    0      ; # u_lut_dtc_dly  所在列 (占位)
set BASE_Y_DLY    100    ; # u_lut_dtc_dly  起始行 (占位)
set BASE_X_DLY2   2      ; # u_lut_dtc_dly2 所在列 (占位, 必须与 dly 不同列)
set BASE_Y_DLY2   100    ; # u_lut_dtc_dly2 起始行 (占位)
set PB_HEIGHT     70     ; # pblock 高度 (需 >= 64)

# 执行约束
place_carry_chain $carry_dly  $BASE_X_DLY  $BASE_Y_DLY
place_carry_chain $carry_dly2 $BASE_X_DLY2 $BASE_Y_DLY2

make_dtc_pblock pblock_dtc_dly  "*lut_dtc_top/u_lut_dtc_dly/*"  $BASE_X_DLY  $BASE_Y_DLY  $PB_HEIGHT
make_dtc_pblock pblock_dtc_dly2 "*lut_dtc_top/u_lut_dtc_dly2/*" $BASE_X_DLY2 $BASE_Y_DLY2 $PB_HEIGHT
