#!/bin/zsh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
SIMS="$DIR/.."
SRC="$DIR/../.."

cd "$DIR"

ghdl -a --std=08 \
    "$SRC/ip_defs_pkg.vhd" \
    "$SRC/crc_gen.vhd" \
    "$SRC/async_fifo.vhd" \
    "$SRC/packet_tx.vhd" \
    "$SIMS/packet_tx_tb.vhd"

ghdl -e --std=08 packet_tx_tb
ghdl -r --std=08 packet_tx_tb --vcd="$DIR/wave.vcd" --stop-time=50us

open -a gtkwave "$DIR/wave.vcd"
