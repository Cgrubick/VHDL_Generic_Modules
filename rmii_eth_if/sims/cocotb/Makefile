# ============================================================
# Makefile – cocotb testbench for packet_tx
#
# Requirements:
#   pip install cocotb
#   GHDL (https://github.com/ghdl/ghdl) installed and on PATH
#
# Usage:
#   make                        # run all tests with GHDL
#   make SIM=questa             # run with ModelSim/Questa instead
#   make TESTCASE=test_single_small_packet   # run one test
#
# ============================================================

SIM          ?= questa
TOPLEVEL_LANG = vhdl

# Source files in dependency order
VHDL_SOURCES  = $(realpath ../ip_defs_pkg.vhd)
VHDL_SOURCES += $(realpath ../crc_gen.vhd)
VHDL_SOURCES += $(realpath ../async_fifo.vhd)
VHDL_SOURCES += $(realpath ../packet_tx.vhd)

TOPLEVEL = packet_tx
MODULE   = test_packet_tx

# GHDL: use VHDL-2008 for std_logic_vector shift operations
ifeq ($(SIM),ghdl)
    EXTRA_ARGS += --std=08
endif

# Questa/ModelSim: compile with VHDL-2008
ifeq ($(SIM),questa)
    VHDL_COMPILE_ARGS += -2008
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
