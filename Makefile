# Simulator settings
SIM?=ghdl
WAVES=1
SIM_ARGS?=--wave=waveform.ghw

# Simulation source files
TOPLEVEL_LANG?=vhdl
VHDL_SOURCES+=$(PWD)/serpent_pkg.vhd
VHDL_SOURCES+=$(PWD)/serpent.vhd
TOPLEVEL=serpent
MODULE=test

# Simulate with default `make` command
include $(shell cocotb-config --makefiles)/Makefile.sim

# `make show` function to show the waveform
show:
	gtkwave waveform.ghw waveview.gtkw --rcvar 'use_big_fonts 1'

# `make compile` function to compile the source to check for errors
compile:
	ghdl -a serpent_pkg.vhd
	ghdl -a serpent.vhd
	rm work-obj93.cf

clean-all:
	rm -r -f sim_build
	rm -r -f __pycache__
	rm -r -f results.xml
	rm -r -f waveform.ghw