iverilog.exe -o fracn_div .\tb_fractionaln.v ..\rtl_all\fractionaln\*.v
vvp.exe .\fracn_div
echo "gtkwave.exe .\top.vcd"