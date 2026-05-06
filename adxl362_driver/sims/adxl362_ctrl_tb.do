# ============================================================
# adxl362_ctrl_tb.do - ModelSim/Questa simulation script
# Run from: adxl362_driver/sims/
# Usage: do adxl362_ctrl_tb.do
# ============================================================

# ---- Compile -----------------------------------------------
vlib work
vmap work work
vcom -2008 ../ADXL362_ctrl.vhd
vcom -2008 adxl362_ctrl_tb.vhd

vsim -t 1ps work.adxl362_ctrl_tb

configure wave -namecolwidth 300
configure wave -valuecolwidth 150

# ---- Waves -------------------------------------------------
add wave -divider "Clock / Reset"
add wave -radix bin   /adxl362_ctrl_tb/clk
add wave -radix bin   /adxl362_ctrl_tb/rst_n

add wave -divider "Control"
add wave -radix bin   /adxl362_ctrl_tb/command
add wave -radix hex   /adxl362_ctrl_tb/data_in
add wave -radix hex   /adxl362_ctrl_tb/data_out

add wave -divider "SPI Bus"
add wave -radix bin   /adxl362_ctrl_tb/ACL_CSN
add wave -radix bin   /adxl362_ctrl_tb/ACL_SCLK
add wave -radix bin   /adxl362_ctrl_tb/ACL_MOSI
add wave -radix bin   /adxl362_ctrl_tb/ACL_MISO
add wave -radix bin   /adxl362_ctrl_tb/ACL_INT

add wave -divider "DUT Internals"
add wave -radix ascii /adxl362_ctrl_tb/DUT/current_state
add wave -radix bin   /adxl362_ctrl_tb/DUT/bit_done
add wave -radix bin   /adxl362_ctrl_tb/DUT/bit_fail
add wave -radix hex   /adxl362_ctrl_tb/DUT/miso_sreg
add wave -radix hex   /adxl362_ctrl_tb/DUT/mosi_sreg

# ---- Run ---------------------------------------------------
run 2 us
wave zoom full
