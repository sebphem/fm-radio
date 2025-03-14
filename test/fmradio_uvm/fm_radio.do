
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# add architecture

vlog -work work "../../sv/add.sv"
vlog -work work "../../sv/demodulate.sv"
vlog -work work "../../sv/divide.sv"
vlog -work work "../../sv/fifo.sv"
vlog -work work "../../sv/fir_cmplx.sv"
vlog -work work "../../sv/fir.sv"
vlog -work work "../../sv/fm_radio.sv"
vlog -work work "../../sv/gain.sv"
vlog -work work "../../sv/global.sv"
vlog -work work "../../sv/iir.sv"
vlog -work work "../../sv/multiply.sv"
vlog -work work "../../sv/qarctan.sv"
vlog -work work "../../sv/readIQ.sv"
vlog -work work "../../sv/sub.sv"

# start basic simulation
vsim -voptargs=+acc +notimingchecks -L work work.fm_radio -wlf fm_radio.wlf

# run -all
