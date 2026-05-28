SIM_OUT = sim_async_fifo

RTL = \
	rtl/sync_2ff.sv \
	rtl/fifo_mem.sv \
	rtl/async_fifo.sv

TB = \
	tb/tb_async_fifo.sv

.PHONY: all sim lint waves clean reports

all: sim

sim:
	iverilog -g2012 -o $(SIM_OUT) $(RTL) $(TB)
	vvp $(SIM_OUT)

lint:
	verilator --lint-only -Wall $(RTL)

waves:
	gtkwave dump.vcd

reports:
	mkdir -p reports
	verilator --lint-only -Wall $(RTL) > reports/verilator_lint.log 2>&1
	iverilog -g2012 -o $(SIM_OUT) $(RTL) $(TB)
	vvp $(SIM_OUT) | tee reports/simulation_summary.log

clean:
	rm -f $(SIM_OUT)
	rm -f dump.vcd
	rm -rf obj_dir