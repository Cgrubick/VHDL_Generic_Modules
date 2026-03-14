
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ip_defs_pkg.all;



entity packet_rx_tb is 
end entity packet_rx_tb;

architecture rtl of packet_rx_tb is
    component packet_rx is
        port (
            clk             : in std_logic;
            reset_n         : in std_logic;
            RXD             : in std_logic_vector(1 downto 0);
            RXDV            : in std_logic;
            M_AXI_S_TVALID  : out std_logic;
            M_AXI_S_TDATA   : out std_logic_vector(7 downto 0);
            M_AXI_S_TLAST   : out std_logic
        );
    end component;

    signal clk              : std_logic;
    signal reset_n          : std_logic;
    signal RXD              : std_logic_vector(1 downto 0);
    signal RXDV             : std_logic;
    signal M_AXI_S_TVALID   : std_logic;
    signal M_AXI_S_TDATA    : std_logic_vector(7 downto 0);
    signal M_AXI_S_TLAST    : std_logic;
    
begin

    packet_recv: packet_rx
        port map (
            clk             => clk,
            reset_n         => reset_n,
            RXD             => RXD,
            RXDV            => RXDV,
            M_AXI_S_TVALID  => M_AXI_S_TVALID,
            M_AXI_S_TDATA   => M_AXI_S_TDATA,
            M_AXI_S_TLAST   => M_AXI_S_TLAST
        );

    -- 100 MHz clock gen
    process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process;
    

end architecture;




