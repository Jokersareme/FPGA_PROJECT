@echo off
REM ============================================================================
REM  SSC vs DTC gain/phase_align calibration verification
REM  Runs two iverilog sims (SSC OFF / SSC ON) and prints the result.
REM
REM  NOTE: iverilog cannot read the Chinese workbuddy path, so we copy the
REM  needed .v files into %TEMP% (ASCII) and compile/run there. The .vvp and
REM  temp copy are removed afterwards -> essentially no disk footprint.
REM ============================================================================
set IV="D:\Program Files\iverilog\bin\iverilog"
set VVP="D:\Program Files\iverilog\bin\vvp"
set SRC=%~dp0
set TMP=%TEMP%\ssc_verify_tmp

if exist "%TMP%" rmdir /s /q "%TMP%"
mkdir "%TMP%"

copy "%SRC%tb_dtc_ssc.v"                                   "%TMP%" >nul
copy "%SRC%..\src\dtc\cal_sign_gen.v"                     "%TMP%" >nul
copy "%SRC%..\src\dtc\dtc_gain_lms_cal.v"                 "%TMP%" >nul
copy "%SRC%..\src\dtc\phase_align_cal.v"                  "%TMP%" >nul

cd /d "%TMP%"

echo ==================== RUN 1 : SSC OFF ====================
%IV% -g2012 -DSSC_ON=0 -o ssc_off.vvp -s tb tb_dtc_ssc.v cal_sign_gen.v dtc_gain_lms_cal.v phase_align_cal.v
if errorlevel 1 goto fail
%VVP% ssc_off.vvp

echo ==================== RUN 2 : SSC ON  ====================
%IV% -g2012 -DSSC_ON=1 -o ssc_on.vvp  -s tb tb_dtc_ssc.v cal_sign_gen.v dtc_gain_lms_cal.v phase_align_cal.v
if errorlevel 1 goto fail
%VVP% ssc_on.vvp

:fail
echo.
echo [done] cleaning temp dir...
cd /d "%SRC%"
rmdir /s /q "%TMP%"
pause
