# Compile
vlib work
vmap work work
vcom -2008 ../src/ip_defs_pkg.vhd
vcom -2008 ../packet_rx.vhd
vcom -2008 ../tb/packet_rx_tb.vhd

# Simulate
vsim work.packet_rx_tb

# Add waves
add wave -divider "Clock/Reset"
add wave -radix bin /packet_rx_tb/clk
add wave -radix bin /packet_rx_tb/reset_n

add wave -divider "RMII RX"
add wave -radix bin /packet_rx_tb/RXDV
add wave -radix hex /packet_rx_tb/RXD

add wave -divider "AXI Stream Out"
add wave -radix bin /packet_rx_tb/M_AXI_S_TVALID
add wave -radix hex /packet_rx_tb/M_AXI_S_TDATA
add wave -radix bin /packet_rx_tb/M_AXI_S_TLAST

# Run
run 1 us