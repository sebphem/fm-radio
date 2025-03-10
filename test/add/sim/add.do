
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# add architecture
vlog -work work "../../../sv/fifo.sv"
vlog -work work "../../../sv/add.sv"
vlog -work work "../tb.sv"

# start basic simulation
vsim -voptargs=+acc +notimingchecks -L work work.add_tb -wlf add_tb.wlf

run -all