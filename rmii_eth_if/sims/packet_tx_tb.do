# ============================================================
# sim.do - ModelSim/Questa simulation script for packet_tx_tb
# Run from: rmii_eth_if/sims/
# Usage: do sim.do
# ============================================================

# ---- Compile -----------------------------------------------
file mkdir ../sim_build
vlib ../sim_build/work
vmap work ../sim_build/work
vcom -2008 ../ip_defs_pkg.vhd
vcom -2008 ../crc_gen.vhd
vcom -2008 ../async_fifo.vhd
vcom -2008 ../packet_tx.vhd
vcom -2008 packet_tx_tb.vhd
vsim -t 1ps -wlf ../sim_build/vsim.wlf work.packet_tx_tb

configure wave -namecolwidth 350
configure wave -valuecolwidth 150
# ---- Simulate ----------------------------------------------

# ---- Waves -------------------------------------------------
add wave -divider "Clock / Reset"
add wave -radix bin              /packet_tx_tb/clk
add wave -radix bin              /packet_tx_tb/reset_n

add wave -divider "AXI-Stream In"
add wave -radix bin              /packet_tx_tb/S_AXI_S_TVALID
add wave -radix hex              /packet_tx_tb/S_AXI_S_TDATA
add wave -radix bin              /packet_tx_tb/S_AXI_S_TLAST
add wave -radix bin              /packet_tx_tb/S_AXI_S_TREADY

add wave -divider "RMII TX"
add wave -radix bin              /packet_tx_tb/ETH_TXEN
add wave -radix hex              /packet_tx_tb/ETH_TXD

add wave -divider "DUT Internals"
add wave -radix ascii            /packet_tx_tb/test_name
add wave -radix unsigned         /packet_tx_tb/DUT/current_state
add wave -radix unsigned         /packet_tx_tb/DUT/packet_count
add wave -radix bin              /packet_tx_tb/DUT/tx_start
add wave -radix bin              /packet_tx_tb/DUT/preamble_done
add wave -radix bin              /packet_tx_tb/DUT/header_done
add wave -radix bin              /packet_tx_tb/DUT/data_done
add wave -radix bin              /packet_tx_tb/DUT/crc_en
add wave -radix hex              /packet_tx_tb/DUT/crc_in
add wave -radix hex              /packet_tx_tb/DUT/crc_out
add wave -radix hex              /packet_tx_tb/DUT/eth_packet_header

add wave -divider "FIFO"
add wave -radix bin              /packet_tx_tb/DUT/wr_rst_n
add wave -radix bin              /packet_tx_tb/DUT/wr_en   
add wave -radix hex              /packet_tx_tb/DUT/wr_data 
add wave -radix bin              /packet_tx_tb/DUT/wr_full
add wave -radix bin              /packet_tx_tb/DUT/wr_afull
add wave -radix bin              /packet_tx_tb/DUT/rd_rst_n
add wave -radix bin              /packet_tx_tb/DUT/rd_en   
add wave -radix hex              /packet_tx_tb/DUT/rd_data 
add wave -radix bin              /packet_tx_tb/DUT/rd_empty
add wave -radix bin              /packet_tx_tb/DUT/rd_aempty

add wave -divider "Decoded Packet"
add wave -radix hex  /packet_tx_tb/DUT/mac_destination
add wave -radix hex  /packet_tx_tb/DUT/mac_source
add wave -radix hex  /packet_tx_tb/DUT/eth_type_length
add wave -radix hex  /packet_tx_tb/DUT/ip_source
add wave -radix hex  /packet_tx_tb/DUT/ip_destination
add wave -radix hex  /packet_tx_tb/DUT/udp_port_src
add wave -radix hex  /packet_tx_tb/DUT/udp_port_dest
add wave -radix hex  /packet_tx_tb/DUT/udp_length
add wave -radix hex  /packet_tx_tb/DUT/udp_checksum

# ---- Run ---------------------------------------------------
run 30 us
wave zoom full
