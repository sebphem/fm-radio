setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# add architecture
vlog -work work "../../../sv/global.sv"
vlog -work work "../../../sv/fifo.sv"
vlog -work work "../../../sv/fir_cmplx.sv"
vlog -work work "../tb.sv"

vsim -voptargs=+acc +notimingchecks -L work work.fir_cmplx_tb -wlf fir_cmplx_tb.wlfs

add wave -noupdate -group fir_cmplx_tb
add wave -noupdate -group fir_cmplx_tb -radix hexadecimal /fir_cmplx_tb/*

add wave -noupdate -group /fir_cmplx_tb/x_real_in_fif
add wave -noupdate -group /fir_cmplx_tb/x_real_in_fifo -radix hexadecimal /fir_cmplx_tb/x_real_in_fifo/*

add wave -noupdate -group /fir_cmplx_tb/x_imag_in_fifo
add wave -noupdate -group /fir_cmplx_tb/x_imag_in_fifo -radix hexadecimal /fir_cmplx_tb/x_imag_in_fifo/*

add wave -noupdate -group /fir_cmplx_tb/fir_cmplx_inst
add wave -noupdate -group /fir_cmplx_tb/fir_cmplx_inst -radix hexadecimal /fir_cmplx_tb/fir_cmplx_inst/*

add wave -noupdate -group /fir_cmplx_tb/y_real_out_fifo
add wave -noupdate -group /fir_cmplx_tb/y_real_out_fifo -radix hexadecimal /fir_cmplx_tb/y_real_out_fifo/*

add wave -noupdate -group /fir_cmplx_tb/y_imag_out_fifo
add wave -noupdate -group /fir_cmplx_tb/y_imag_out_fifo -radix hexadecimal /fir_cmplx_tb/y_imag_out_fifo/*
#run -all