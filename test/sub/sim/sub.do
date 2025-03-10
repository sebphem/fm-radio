
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# add architecture
vlog -work work "../../../sv/fifo.sv"
vlog -work work "../../../sv/sub.sv"
vlog -work work "../tb.sv"

# start basic simulation
vsim -voptargs=+acc +notimingchecks -L work work.sub_tb -wlf sub_tb.wlf

run -all