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
add wave -radix bin      /adxl362_ctrl_tb/clk
add wave -radix bin      /adxl362_ctrl_tb/rst_n

add wave -divider "Top-level Control"
add wave -radix bin      /adxl362_ctrl_tb/command
add wave -radix hex      /adxl362_ctrl_tb/imu_reg
add wave -radix hex      /adxl362_ctrl_tb/data_out
add wave -radix bin      /adxl362_ctrl_tb/DUT/pbit_done
add wave -radix bin      /adxl362_ctrl_tb/DUT/pbit_fail

add wave -divider "SPI Bus (pins)"
add wave -radix bin      /adxl362_ctrl_tb/ACL_CSN
add wave -radix bin      /adxl362_ctrl_tb/ACL_SCLK
add wave -radix bin      /adxl362_ctrl_tb/ACL_MOSI
add wave -radix bin      /adxl362_ctrl_tb/ACL_MISO
add wave -radix bin      /adxl362_ctrl_tb/ACL_INT

add wave -divider "FSM"
add wave -radix ascii    /adxl362_ctrl_tb/DUT/current_state

add wave -divider "SPI Clock Divider"
add wave -radix bin      /adxl362_ctrl_tb/DUT/spi_clk
add wave -radix unsigned /adxl362_ctrl_tb/DUT/spi_clk_counter

add wave -divider "Bit Counter"
add wave -radix unsigned /adxl362_ctrl_tb/DUT/bit_counter
add wave -radix bin      /adxl362_ctrl_tb/DUT/byte_done

add wave -divider "Shift Registers"
add wave -radix hex      /adxl362_ctrl_tb/DUT/mosi_sreg
add wave -radix hex      /adxl362_ctrl_tb/DUT/miso_sreg
add wave -radix hex      /adxl362_ctrl_tb/DUT/imu_reg_d

add wave -divider "ADXL362 Status Reg"
add wave -radix hex      /adxl362_ctrl_tb/DUT/status_reg
add wave -radix bin      /adxl362_ctrl_tb/DUT/err_user
add wave -radix bin      /adxl362_ctrl_tb/DUT/awake
add wave -radix bin      /adxl362_ctrl_tb/DUT/inact
add wave -radix bin      /adxl362_ctrl_tb/DUT/act
add wave -radix bin      /adxl362_ctrl_tb/DUT/fifo_overflow
add wave -radix bin      /adxl362_ctrl_tb/DUT/fifo_watermark
add wave -radix bin      /adxl362_ctrl_tb/DUT/fifo_ready
add wave -radix bin      /adxl362_ctrl_tb/DUT/data_ready

add wave -divider "Axis / Temp Regs"
add wave -radix hex      /adxl362_ctrl_tb/DUT/x_reg
add wave -radix hex      /adxl362_ctrl_tb/DUT/y_reg
add wave -radix hex      /adxl362_ctrl_tb/DUT/z_reg
add wave -radix hex      /adxl362_ctrl_tb/DUT/temp_L_reg
add wave -radix hex      /adxl362_ctrl_tb/DUT/temp_H_reg

#add wave -divider "SPI CLK generation"
#add wave -radix bin      /adxl362_ctrl_tb/DUT/spi_clk
#add wave -radix bin      /adxl362_ctrl_tb/DUT/spi_clk_counter
# ---- Run ---------------------------------------------------
run 50 us
wave zoom full
