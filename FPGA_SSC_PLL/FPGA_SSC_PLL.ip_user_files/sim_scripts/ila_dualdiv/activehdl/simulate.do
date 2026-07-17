transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+ila_dualdiv  -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.ila_dualdiv xil_defaultlib.glbl

do {ila_dualdiv.udo}

run 1000ns

endsim

quit -force
