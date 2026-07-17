transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xpm
vlib riviera/xil_defaultlib

vmap xpm riviera/xpm
vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xpm  -incr "+incdir+../../../../FPGA_SSC_PLL.gen/sources_1/ip/vio_1/hdl/verilog" "+incdir+../../../../FPGA_SSC_PLL.gen/sources_1/ip/vio_1/hdl" -l xpm -l xil_defaultlib \
"D:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"D:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  -incr \
"D:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../FPGA_SSC_PLL.gen/sources_1/ip/vio_1/hdl/verilog" "+incdir+../../../../FPGA_SSC_PLL.gen/sources_1/ip/vio_1/hdl" -l xpm -l xil_defaultlib \
"../../../../FPGA_SSC_PLL.gen/sources_1/ip/vio_1/sim/vio_1.v" \

vlog -work xil_defaultlib \
"glbl.v"

