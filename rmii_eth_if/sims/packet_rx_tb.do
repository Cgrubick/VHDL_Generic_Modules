# ============================================================
# sim.do - ModelSim/Questa simulation script for packet_rx_tb
# Run from: rmii_eth_if/sims/
# Usage: do sim.do
# ============================================================

# ---- Compile -----------------------------------------------
vlib work
vmap work work
vcom -2008 ../ip_defs_pkg.vhd
vcom -2008 ../packet_rx.vhd
vcom -2008 packet_rx_tb.vhd
vsim -t 1ps work.packet_rx_tb

configure wave -namecolwidth 350
configure wave -valuecolwidth 150
# ---- Simulate ----------------------------------------------

# ---- Waves -------------------------------------------------
add wave -divider "Clock / Reset"
add wave -radix bin              /packet_rx_tb/clk
add wave -radix bin              /packet_rx_tb/reset_n

add wave -divider "RMII RX"
add wave -radix bin              /packet_rx_tb/RXDV
add wave -radix hex              /packet_rx_tb/RXD

add wave -divider "AXI-Stream Out"
add wave -radix bin              /packet_rx_tb/M_AXI_S_TVALID
add wave -radix hex              /packet_rx_tb/M_AXI_S_TDATA
add wave -radix bin              /packet_rx_tb/M_AXI_S_TLAST

add wave -divider "DUT Internals"
add wave -radix ascii            /packet_rx_tb/test_name
add wave -radix unsigned         /packet_rx_tb/DUT/current_state
add wave -radix unsigned         /packet_rx_tb/DUT/state_counter
add wave -radix hex              /packet_rx_tb/DUT/preamble_sfd_buff
add wave -radix hex              /packet_rx_tb/DUT/preamble_sfd_buff_next
add wave -radix hex              /packet_rx_tb/DUT/header_buffer
add wave -radix hex              /packet_rx_tb/DUT/data_buffer
add wave -radix bin              /packet_rx_tb/DUT/packet_start
add wave -radix bin              /packet_rx_tb/DUT/packet_done
add wave -radix hex              /packet_rx_tb/DUT/packet_dest


add wave -divider "Decoded Packet"
add wave -radix hex  /packet_rx_tb/DUT/udp_checksum   
add wave -radix hex  /packet_rx_tb/DUT/udp_length     
add wave -radix hex  /packet_rx_tb/DUT/udp_port_dest  
add wave -radix hex  /packet_rx_tb/DUT/udp_port_src   
add wave -radix hex  /packet_rx_tb/DUT/ip_destination 
add wave -radix hex  /packet_rx_tb/DUT/ip_source      
add wave -radix hex  /packet_rx_tb/DUT/eth_type_length
add wave -radix hex  /packet_rx_tb/DUT/mac_source     
add wave -radix hex  /packet_rx_tb/DUT/mac_destination
add wave -radix hex  /packet_rx_tb/DUT/data_buffer

# ---- Run ---------------------------------------------------
run 25 us
wave zoom full