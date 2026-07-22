@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo  DTC PLL Top Simulation - iverilog/gtkwave
echo ==========================================

set SRC=src
set MOD=models

iverilog -g2012 -o main.vvp ^
    %MOD%\carry8_model.v ^
    xilinx_sim.v ^
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
    tb_top.v

if errorlevel 1 (
    echo [FAIL] Compilation failed
    pause
    exit /b 1
)
echo [OK] Compiled

vvp main.vvp
if errorlevel 1 (
    echo [FAIL] Simulation error
    pause
    exit /b 1
)
echo [OK] Simulation complete - VCD: tb_top.vcd
echo Opening GTKWave...
start "" gtkwave tb_top.vcd
pause
