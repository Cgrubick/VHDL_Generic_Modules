library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ip_defs_pkg.all;

-- FOR RMII interface, for use specifically with the nexys a7 digilent fpga board
-- This is a UDP/Ethernet packet receiver running over a 2-bit MII (Media Independent Interface).
-- It receives raw Ethernet frames from a PHY chip and extracts the UDP payload, outputting it over
-- an AXI-Stream interface.

entity packet_rx is
    port (
        clk            : in  std_logic;
        reset_n        : in  std_logic;
        RXD            : in  std_logic_vector(1 downto 0);
        RXDV           : in  std_logic;
        M_AXI_S_TVALID : out std_logic;
        M_AXI_S_TDATA  : out std_logic_vector(7 downto 0);
        M_AXI_S_TLAST  : out std_logic
    );
end entity packet_rx;

architecture rtl of packet_rx is

    constant MII_WIDTH       : integer := 2;
    constant FIRST_PACKET_IGNORE : integer := 0;

    constant HEADER_BYTES    : integer := 42;
    constant ETH_HEADER_BITS : integer := HEADER_BYTES * 8;  -- 336 bits

    type rxd_z_arr is array (0 to 2) of std_logic_vector(1 downto 0);
    signal rxd_z : rxd_z_arr;

    signal rxdv_z             : std_logic_vector(2 downto 0);

    signal first_packet_count : unsigned(7 downto 0);
    signal packet_done        : std_logic;
    signal packet_start       : std_logic;

    signal data_buffer        : std_logic_vector(7 downto 0);
    signal preamble_sfd_buff  : std_logic_vector(63 downto 0);
    signal preamble_sfd_buff_next : std_logic_vector(63 downto 0);

    -- Header shift register: 42 bytes wide
    signal header_buffer      : std_logic_vector(ETH_HEADER_BITS-1 downto 0);

    type eth_states is (IDLE_S, PREAMBLE_SFD_S, HEADER_S, DATA_S);
    signal current_state      : eth_states;
    signal state_counter      : unsigned(31 downto 0);

    signal data_valid         : std_logic;
    signal data_last          : std_logic;

    signal packet_dest        : unsigned(47 downto 0);

    signal mac_destination    : std_logic_vector(47 downto 0);
    signal mac_source         : std_logic_vector(47 downto 0);
    signal eth_type_length    : std_logic_vector(15 downto 0);
    signal ip_source          : std_logic_vector(31 downto 0);
    signal ip_destination     : std_logic_vector(31 downto 0);
    signal udp_port_src       : std_logic_vector(15 downto 0);
    signal udp_port_dest      : std_logic_vector(15 downto 0);
    signal udp_length         : std_logic_vector(15 downto 0);
    signal udp_checksum       : std_logic_vector(15 downto 0);

begin

    process (clk, reset_n)
    begin
        if reset_n = '0' then
            rxd_z              <= (others => (others => '0'));
            rxdv_z             <= (others => '0');
            first_packet_count <= (others => '0');
        elsif rising_edge(clk) then
            rxd_z(0) <= RXD;
            rxd_z(1) <= rxd_z(0);
            rxd_z(2) <= rxd_z(1);

            rxdv_z(0) <= RXDV;
            rxdv_z(1) <= rxdv_z(0);
            rxdv_z(2) <= rxdv_z(1);

            if packet_done = '1' and first_packet_count < FIRST_PACKET_IGNORE then
                first_packet_count <= first_packet_count + 1;
            end if;
        end if;
    end process;

    -- --------------------------------------------------------
    -- State counter: resets on state change
    -- --------------------------------------------------------
    process (clk, reset_n)
    begin
        if reset_n = '0' then
            state_counter <= (others => '0');
        elsif rising_edge(clk) then
            -- increment every clock; reset when we enter HEADER_S
            -- (state_counter used to count bytes received in HEADER_S)
            if current_state = HEADER_S then
                state_counter <= state_counter + 1;
            else
                state_counter <= (others => '0');
            end if;
        end if;
    end process;

    state_logic : process (clk, reset_n)
    begin
        if reset_n = '0' then
            current_state <= IDLE_S;
        elsif rising_edge(clk) then
            case current_state is
                when IDLE_S =>
                    if packet_start = '1' then
                        current_state <= PREAMBLE_SFD_S;
                    end if;

                when PREAMBLE_SFD_S =>
                    if preamble_sfd_buff_next = x"D555555555555555" then
                        current_state <= HEADER_S;
                    end if;
                    if packet_done = '1' then
                        current_state <= IDLE_S;
                    end if;

                when HEADER_S =>
                    if packet_done = '1' then
                        current_state <= IDLE_S;
                    -- 42 bytes × 4 clocks/byte = 168 clocks; counter is in clocks
                    elsif state_counter = (HEADER_BYTES * 4) - 1 then
                        current_state <= DATA_S;
                    end if;

                when DATA_S =>
                    if packet_done = '1' then
                        current_state <= IDLE_S;
                    end if;

                when others =>
                    current_state <= IDLE_S;
            end case;
        end if;
    end process state_logic;

    process (clk, reset_n)
    begin
        if reset_n = '0' then
            preamble_sfd_buff <= (others => '0');
            header_buffer     <= (others => '0');
            data_buffer       <= (others => '0');
            data_valid        <= '0';
            data_last         <= '0';
        elsif rising_edge(clk) then
            data_valid <= '0';
            data_last  <= '0';

            if current_state = PREAMBLE_SFD_S then
                preamble_sfd_buff <= preamble_sfd_buff_next;
            end if;
            
            if current_state = HEADER_S then
                header_buffer <= rxd_z(0) & header_buffer(ETH_HEADER_BITS-1 downto 2);
            end if;

            if current_state = DATA_S then
                data_buffer <= rxd_z(0) & data_buffer(7 downto 2);

                if state_counter(1 downto 0) = "11" then
                    if ((CHECK_DEST /= '1') OR (packet_dest = unsigned(FPGA_MAC))) then
                        data_valid <= '1';
                    end if;
                end if;

                if packet_done = '1' then
                    data_last <= '1';
                end if;
            end if;
        end if;
    end process;

    packet_start <= '1' when (rxdv_z(2) = '0' and rxdv_z(1) = '1') else '0';
    packet_done  <= '1' when (rxdv_z(2) = '1' and rxdv_z(1) = '0') else '0';

    preamble_sfd_buff_next(63 downto 62) <= rxd_z(0) when reset_n = '1' else "00";
    preamble_sfd_buff_next(61 downto 0)  <= preamble_sfd_buff(63 downto 2) when reset_n = '1' else (others => '0');

    mac_destination <= header_buffer(ETH_HEADER_BITS-1   downto ETH_HEADER_BITS-48);
    mac_source      <= header_buffer(ETH_HEADER_BITS-49  downto ETH_HEADER_BITS-96);
    eth_type_length <= header_buffer(ETH_HEADER_BITS-97  downto ETH_HEADER_BITS-112);
    ip_source       <= header_buffer(ETH_HEADER_BITS-113 downto ETH_HEADER_BITS-144);
    ip_destination  <= header_buffer(ETH_HEADER_BITS-145 downto ETH_HEADER_BITS-176);
    udp_port_src    <= header_buffer(ETH_HEADER_BITS-177 downto ETH_HEADER_BITS-192);
    udp_port_dest   <= header_buffer(ETH_HEADER_BITS-193 downto ETH_HEADER_BITS-208);
    udp_length      <= header_buffer(ETH_HEADER_BITS-209 downto ETH_HEADER_BITS-224);
    udp_checksum    <= header_buffer(ETH_HEADER_BITS-225 downto ETH_HEADER_BITS-240);

    packet_dest <= unsigned(mac_destination);

    -- AXI-Stream outputs
    M_AXI_S_TVALID <= data_valid;
    M_AXI_S_TDATA  <= data_buffer;
    M_AXI_S_TLAST  <= data_last;

end rtl;