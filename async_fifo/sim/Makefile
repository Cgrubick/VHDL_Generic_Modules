# Makefile

# defaults
SIM          ?= ghdl
TOPLEVEL_LANG = vhdl

VHDL_SOURCES += $(PWD)/../async_fifo.vhd

TOPLEVEL = async_fifo
MODULE   = async_fifo_tb

ifeq ($(SIM),ghdl)
    EXTRA_ARGS += --std=08
    SIM_ARGS   += --wave=wave.ghw
endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim