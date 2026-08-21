# Makefile

# defaults
SIM ?= ghdl
EXTRA_ARGS += --std=08
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += $(PWD)/../async_fifo.vhd
# use VHDL_SOURCES for VHDL files

# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
COCOTB_TOPLEVEL = async_fifo

# COCOTB_TEST_MODULES is the basename of the Python test file(s)
COCOTB_TEST_MODULES = async_fifo_tb
SIM_ARGS += --wave=wave.ghw

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim