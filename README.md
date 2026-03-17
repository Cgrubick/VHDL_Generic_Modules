# VHDL_Generic_Modules

A collection of reusable, generic VHDL modules for FPGA development. Designed to be portable across tools (Vivado, Quartus, GHDL) and easily dropped into larger designs.

---

## Modules

### `baud_gen.vhd`
Configurable baud rate generator. Produces a clock enable tick at the desired baud rate given a system clock input. Generic parameters for system clock frequency and target baud rate.

### `counter_with_tc.vhd`
Up-counter with terminal count (TC) output. Asserts TC for one clock cycle when the counter reaches its maximum value before rolling over. Useful for timing and event generation.

### `hex_to_seven_seg.vhd`
Combinational hex-to-seven-segment display decoder. Converts a 4-bit hex nibble to the appropriate 7-segment encoding. Active-low output compatible with most FPGA dev board displays.

### `pwm.vhd`
Pulse-width modulation signal generator. Configurable period and duty cycle via generics or runtime inputs. Suitable for motor control, LED dimming, and DAC approximation.

### `timer.vhd`
General-purpose countdown/interval timer. Generates a pulse output at a configurable interval. Built on top of a clock enable for easy frequency scaling.

### `uart_rx.vhd`
UART receiver. Deserializes incoming serial data at a configurable baud rate. Outputs a received byte with a data-valid strobe. Includes basic framing error detection.

---

## Directory Structure