@echo off
cd /d "C:\Users\Administrator\Desktop\GS\FPGA_PROJECT\FPGA_PROJECT\RTL\testbench\workbuddy"

echo ==========================================
echo  FPGA SSC PLL + DTC Simulation (Icarus)
echo ==========================================

:: Set Icarus Verilog path (adjust if your install path is different)
set "IVERILOG_PATH=D:\Program Files\iverilog\bin"
set "PATH=%IVERILOG_PATH%;%PATH%"

:: Verify iverilog exists
iverilog -V >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] iverilog not found in %IVERILOG_PATH%
    echo Please install Icarus Verilog or adjust IVERILOG_PATH in this script.
    pause
    exit /b 1
)

:: Compile all Verilog files
:: Order: models first, then src, then tb
echo [1/3] Compiling Verilog sources...

iverilog -g2012 -o sim.out ^
  models/xilinx_sim.v ^
  models/carry8_model.v ^
  src/fractionaln/dff.v ^
  src/fractionaln/reg_sync.v ^
  src/fractionaln/reg_async.v ^
  src/fractionaln/div_2.v ^
  src/fractionaln/div_45.v ^
  src/fractionaln/div_89.v ^
  src/fractionaln/dual_div.v ^
  src/fractionaln/efm.v ^
  src/fractionaln/hk_efm.v ^
  src/fractionaln/mash111.v ^
  src/fractionaln/p_counter.v ^
  src/fractionaln/s_counter.v ^
  src/fractionaln/calculate_ps.v ^
  src/fractionaln/fractionaln.v ^
  src/dtc/dtc_calibrator.v ^
  src/dtc/dtc_comp.v ^
  src/dtc/lut_dtc.v ^
  src/dtc/lut_dtc_cal.v ^
  src/dtc/lut_dtc_top.v ^
  src/ssc_controller.v ^
  src/fpga_ssc_pll_top.v ^
  tb_top.v

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Compilation failed!
    pause
    exit /b 1
)

echo [2/3] Running simulation...
vvp sim.out

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Simulation failed!
    pause
    exit /b 1
)

echo.
echo [3/3] Done.
echo VCD file: tb_top.vcd
echo.
pause
