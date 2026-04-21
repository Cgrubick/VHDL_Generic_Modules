library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ip_defs_pkg is
    -- All multi-byte constants are stored byte-reversed.
    -- packet_tx shifts the header right (LSB-first), which reverses byte order on
    -- the wire, so storing them reversed here cancels it out and gives correct
    -- network byte order at the PHY.
    --
    -- IPv4 (32-bit) -- wire value in comments
    constant FPGA_IP        : std_logic_vector(31 downto 0) := x"5100000A"; -- 10.0.0.81
    constant HOST_IP        : std_logic_vector(31 downto 0) := x"5000000A"; -- 10.0.0.80
    -- UDP ports (16-bit)
    constant FPGA_PORT      : std_logic_vector(15 downto 0) := x"6745";     -- 17767
    constant HOST_PORT      : std_logic_vector(15 downto 0) := x"6745";     -- 17767
    -- MAC addresses (48-bit) -- byte-reversed
    constant FPGA_MAC       : std_logic_vector(47 downto 0) := x"C3C3C3C3C3C3"; -- c3:c3:c3:c3:c3:c3
    constant HOST_MAC       : std_logic_vector(47 downto 0) := x"AF93B4E0FF10"; -- 10:ff:e0:b4:93:af
    constant CHECK_DEST     : std_logic := '1';
end package ip_defs_pkg;