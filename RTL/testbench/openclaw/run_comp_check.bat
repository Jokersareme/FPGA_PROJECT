@echo off
setlocal
cd /d "%~dp0"

echo =====================================================
echo  3rd-Order Compensation Check  (tb_comp_check)
echo =====================================================

set SRC=src
set MOD=models

iverilog -g2012 -o comp_check.vvp ^
    %MOD%\carry8_model.v ^
    xilinx_sim.v ^
    vio_override.v ^
    %SRC%\dtc\lut_dtc.v ^
    %SRC%\dtc\lut_dtc_top.v ^
    %SRC%\dtc\dtc_comp.v ^
    %SRC%\dtc\dtc_calibrator.v ^
    %SRC%\fractionaln\dff.v ^
    %SRC%\fractionaln\reg_async.v ^
    %SRC%\fractionaln\reg_sync.v ^
    %SRC%\fractionaln\div_2.v ^
    %SRC%\fractionaln\div_45.v ^
    %SRC%\fractionaln\div_89.v ^
    %SRC%\fractionaln\dual_div.v ^
    %SRC%\fractionaln\efm.v ^
    %SRC%\fractionaln\hk_efm.v ^
    %SRC%\fractionaln\mash111.v ^
    %SRC%\fractionaln\p_counter.v ^
    %SRC%\fractionaln\s_counter.v ^
    %SRC%\fractionaln\calculate_ps.v ^
    %SRC%\fractionaln\fractionaln.v ^
    %SRC%\ssc_controller.v ^
    %SRC%\fpga_ssc_pll_top.v ^
    tb_comp_check.v

if errorlevel 1 (
    echo [FAIL] Compilation failed
    pause
    exit /b 1
)
echo [OK] Compiled
echo Running...
vvp comp_check.vvp
if errorlevel 1 (
    echo [FAIL] Simulation error
    pause
    exit /b 1
)
echo [OK] VCD: tb_comp_check.vcd
echo Opening GTKWave...
start "" gtkwave tb_comp_check.vcd
pause
