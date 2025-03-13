
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# add architecture
vlog -work work "../../../sv/global.sv"
vlog -work work "../../../sv/fifo.sv"
vlog -work work "../../../sv/multiply.sv"
vlog -work work "../../../sv/divide.sv"
vlog -work work "../../../sv/qarctan.sv"
vlog -work work "../tb.sv"

# start basic simulation
vsim -voptargs=+acc +notimingchecks -L work work.qarctan_tb -wlf qarctan_tb.wlf

run -all