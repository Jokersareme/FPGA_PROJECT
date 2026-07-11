iverilog.exe -o fracn_div .\tb_fractionaln.v ..\all\fracn_div\*.v
vvp.exe .\fracn_div
echo "gtkwave.exe .\top.vcd"