library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ip_defs_pkg.all;


entity packet_tx is
    port (
        clk             : in std_logic;
        reset_n         : in std_logic;
        data_i          : in std_logic_vector(7 downto 0);
        S_AXI_S_TVALID  : in std_logic;
        S_AXI_S_TDATA   : in std_logic_vector(7 downto 0);
        S_AXI_S_TLAST   : in std_logic;
        S_AXI_S_TREADY  : out std_logic;
        ETH_TXD         : out std_logic_vector(1 downto 0);
        ETH_TXEN        : out std_logic
    );
end entity packet_tx;

architecture rtl of packet_tx is


    component crc_32 is
        port (
            crc_in  : in std_logic_vector(31 downto 0);
            crc_en  : in std_logic;
            data    : in std_logic_vector(1 downto 0);
            crc_out : out std_logic_vector(31 downto 0)
        );
    end component;

    constant MII_WIDTH       : integer := 2;
    constant FIRST_PACKET_IGNORE : integer := 0;
    constant HEADER_BYTES    : integer := 42;
    constant ETH_HEADER_BITS : integer := HEADER_BYTES * 8;  -- 336 bits

    
    type eth_states is (IDLE_S, PREAMBLE_S, SFD_S, HEADER_S, DATA_S, FCS_S, WAIT_S);
    signal current_state      : eth_states;
    signal state_counter      : unsigned(31 downto 0);


    -- FIFO
    signal fifo_full        : std_logic;
    signal fifo_empty       : std_logic;
    signal fifo_count       : unsigned(11 downto 0);
    signal fifo_data_o      : std_logic_vector(7 downto 0);

    signal crc_data : std_logic_vector(1 downto 0);
    signal crc_in   : std_logic_vector(31 downto 0);
    signal crc_out  : std_logic_vector(31 downto 0);
    signal crc_en   : std_logic;
begin

    crc: crc_32
    port map (
        crc_in => crc_in,
        crc_en  => crc_en,
        data   => crc_data,
        crc_out => crc_out
    );

    

    S_AXI_S_TREADY <= not fifo_full;

end rtl;