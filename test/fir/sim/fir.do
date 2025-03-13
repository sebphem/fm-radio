
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# add architecture
vlog -work work "../../../sv/global.sv"
vlog -work work "../../../sv/fifo.sv"
vlog -work work "../../../sv/iir.sv"
vlog -work work "../tb.sv"

# start basic simulation
vsim -voptargs=+acc +notimingchecks -L work work.fir_tb -wlf fir_tb.wlfs

add wave -noupdate -group fir_tb
add wave -noupdate -group fir_tb -radix hexadecimal  /fir_tb/*

add wave -noupdate -group /fir_tb/x_in_fifo
add wave -noupdate -group /fir_tb/x_in_fifo -radix hexadecimal  /fir_tb/x_in_fifo/*


add wave -noupdate -group /fir_tb/iir_inst
add wave -noupdate -group /fir_tb/iir_inst -radix hexadecimal  /fir_tb/iir_inst/*

#run -all