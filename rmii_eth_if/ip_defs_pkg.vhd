library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ip_defs_pkg is
    -- IPv4 addresses (32-bit)
    constant FPGA_IP        : std_logic_vector(31 downto 0) := x"C0A80164"; -- 192.168.1.100
    constant HOST_IP        : std_logic_vector(31 downto 0) := x"C0A80165"; -- 192.168.1.101
    -- UDP/TCP ports (16-bit)
    constant FPGA_PORT      : std_logic_vector(15 downto 0) := x"4567";
    constant HOST_PORT      : std_logic_vector(15 downto 0) := x"4567";
    -- MAC addresses (48-bit)
    constant FPGA_MAC       : std_logic_vector(47 downto 0) := x"E86A64E7E830";
    constant HOST_MAC       : std_logic_vector(47 downto 0) := x"E86A64E7E830";
    constant CHECK_DEST     : std_logic := '1';
end package ip_defs_pkg;