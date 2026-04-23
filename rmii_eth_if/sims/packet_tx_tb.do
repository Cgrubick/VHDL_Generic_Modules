# ============================================================
# packet_tx_tb.do - ModelSim/Questa simulation script
# Run from: rmii_eth_if/sims/
# Usage: do packet_tx_tb.do
# ============================================================

# ---- Compile -----------------------------------------------
vlib work
vmap work work
vcom -2008 ../ip_defs_pkg.vhd
vcom -2008 ../crc_gen.vhd
vcom -2008 ../async_fifo.vhd
vcom -2008 ../packet_tx.vhd
vcom -2008 packet_tx_tb.vhd

vsim -t 1ps work.packet_tx_tb

configure wave -namecolwidth 300
configure wave -valuecolwidth 150

# ---- Waves -------------------------------------------------
add wave -divider "Clock / Reset"
add wave -radix bin      /packet_tx_tb/clk
add wave -radix bin      /packet_tx_tb/reset_n

add wave -divider "AXI-S In"
add wave -radix bin      /packet_tx_tb/S_AXI_S_TVALID
add wave -radix hex      /packet_tx_tb/S_AXI_S_TDATA
add wave -radix bin      /packet_tx_tb/S_AXI_S_TLAST
add wave -radix bin      /packet_tx_tb/S_AXI_S_TREADY

add wave -divider "RMII TX"
add wave -radix bin      /packet_tx_tb/ETH_TXEN
add wave -radix hex      /packet_tx_tb/ETH_TXD

add wave -divider "DUT Internals"
add wave -radix ascii    /packet_tx_tb/DUT/current_state
add wave -radix unsigned /packet_tx_tb/DUT/packet_count
add wave -radix bin      /packet_tx_tb/DUT/tx_start

add wave -divider "CRC"
add wave -radix bin      /packet_tx_tb/DUT/crc_rst_n
add wave -radix hex      /packet_tx_tb/DUT/txdata
add wave -radix bin      /packet_tx_tb/DUT/crc_en
add wave -radix hex      /packet_tx_tb/DUT/fcs

add wave -divider "Packet Section flags"	
add wave -radix bin      /packet_tx_tb/DUT/preamble_done 
add wave -radix bin      /packet_tx_tb/DUT/sfd_done 
add wave -radix bin      /packet_tx_tb/DUT/header_done	
add wave -radix bin      /packet_tx_tb/DUT/data_done 	    
add wave -radix bin      /packet_tx_tb/DUT/fcs_done   

add wave -divider "buffers "	
add wave -radix hex      /packet_tx_tb/DUT/preamble_buffer	
add wave -radix hex      /packet_tx_tb/DUT/sfd_buffer		
add wave -radix hex      /packet_tx_tb/DUT/header_buffer 	
add wave -radix hex      /packet_tx_tb/DUT/rd_data_buffer	
add wave -radix hex      /packet_tx_tb/DUT/fcs_buffer	

add wave -divider "FIFO"
add wave -radix bin      /packet_tx_tb/DUT/clk
add wave -radix bin      /packet_tx_tb/DUT/wr_en
add wave -radix hex      /packet_tx_tb/DUT/wr_data
add wave -radix bin      /packet_tx_tb/DUT/wr_full
add wave -radix bin      /packet_tx_tb/DUT/wr_afull
add wave -radix bin      /packet_tx_tb/DUT/rd_en 
add wave -radix hex      /packet_tx_tb/DUT/rd_data
add wave -radix bin      /packet_tx_tb/DUT/rd_empty
add wave -radix bin      /packet_tx_tb/DUT/rd_aempty

# ---- Run ---------------------------------------------------
run 50 us
wave zoom full
