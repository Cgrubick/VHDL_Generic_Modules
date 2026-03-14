library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ip_defs_pkg is
    -- IPv4 addresses (32-bit)
    constant FPGA_IP        : unsigned(31 downto 0) := x"C0A80164"; -- 192.168.1.100
    constant HOST_IP        : unsigned(31 downto 0) := x"C0A80165"; -- 192.168.1.101
    -- UDP/TCP ports (16-bit)
    constant FPGA_PORT      : unsigned(15 downto 0) := x"4567";
    constant HOST_PORT      : unsigned(15 downto 0) := x"4567";
    -- MAC addresses (48-bit)
    constant FPGA_MAC       : unsigned(47 downto 0) := x"E86A64E7E830";
    constant HOST_MAC       : unsigned(47 downto 0) := x"E86A64E7E830";
    constant CHECK_DEST     : std_logic := '1';
end package ip_defs_pkg;