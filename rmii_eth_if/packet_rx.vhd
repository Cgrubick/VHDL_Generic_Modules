library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ip_defs_pkg.all;

-- FOR RMII interface, for use specifically with the nexys a7 digilent fpga board
-- This is a UDP/Ethernet packet receiver running over a 2-bit MII (Media Independent Interface). 
-- It receives raw Ethernet frames from a PHY chip and extracts the UDP payload, outputting it over 
-- an AXI-Stream interface.


entity packet_rx is
    generic (
        FPGA_IP           : std_logic_vector(31 downto 0) := x"C0A80164";
        HOST_IP           : std_logic_vector(31 downto 0) := x"C0A80165";
        FPGA_PORT         : std_logic_vector(15 downto 0) := x"4567";
        HOST_PORT         : std_logic_vector(15 downto 0) := x"4567";
        FPGA_MAC          : std_logic_vector(47 downto 0) := x"e86a64e7e830";
        HOST_MAC          : std_logic_vector(47 downto 0) := x"e86a64e7e829";
        CHECK_DESTINATION : boolean                       := true
    );
    port (
        clk             : in std_logic;
        reset_n         : in std_logic;
        RXD             : in std_logic_vector(1 downto 0);
        RXDV            : in std_logic;
        M_AXI_S_TVALID  : out std_logic;
        M_AXI_S_TDATA   : out std_logic_vector(7 downto 0);
        M_AXI_S_TLAST   : out std_logic
    );
end entity packet_rx;

architecture rtl of packet_rx is
    constant WORD_BYTES             : integer := 4;
    constant MII_WIDTH              : integer := 2;
    constant FIRST_PACKET_IGNORE    : integer := 0;
    constant ETH_HEADER_BITS        : integer := 14*8 + 20*8 + 8*8; -- eth + ipv4 + udp (example)

    constant MAC_DST_MSB            : integer := ETH_HEADER_BITS-1;
    constant MAC_DST_LSB            : integer := ETH_HEADER_BITS-48;
    constant MAC_SRC_MSB            : integer := MAC_DST_LSB-1;
    constant MAC_SRC_LSB            : integer := MAC_SRC_MSB-48+1;
    

    -- Ethernet Sub signals
    -- Ethernet:
    --     mac_destination  = 6 bytes
    --     mac_source       = 6 bytes
    --     eth_type_length  = 2 bytes
    --     IPv4 header      = 20 bytes
    --     UDP header       = 8 bytes
    signal mac_destination : std_logic_vector(47 downto 0);
    signal mac_source      : std_logic_vector(47 downto 0);
    signal eth_type_length : std_logic_vector(15 downto 0);

    signal ip_destination  : std_logic_vector(31 downto 0);
    signal ip_source       : std_logic_vector(31 downto 0);

    signal udp_port_src    : std_logic_vector(15 downto 0);
    signal udp_port_dest   : std_logic_vector(15 downto 0);
    signal udp_length      : std_logic_vector(15 downto 0);
    signal udp_checksum    : std_logic_vector(15 downto 0);



    signal ethernet_header : std_logic_vector(42*8-1 downto 0);
    constant HEADER_BYTES  : integer := ethernet_header'length / 2;

    type rxd_z_arr is array (0 to MII_WIDTH-1) of std_logic_vector(2 downto 0);
    signal rxd_z                    : rxd_z_arr;
    signal rxdv_z                   : unsigned(2 downto 0);
    signal first_packet_count       : unsigned(7 downto 0);
    signal packet_done              : std_logic;
    signal packet_start             : std_logic; 
    -- header and state buffers
    signal data_buffer              : std_logic_vector(7 downto 0);
    signal preamble_sfd_buff        : std_logic_vector(63 downto 0);
    signal preamble_sfd_buff_next   : std_logic_vector(63 downto 0);

    signal header_sreg              : std_logic_vector(ETH_HEADER_BITS-1 downto 0);

    type eth_states is (IDLE_S, PREAMBLE_SFD_S, HEADER_S, DATA_S);

    signal current_state            : eth_states;
    signal next_state               : eth_states;
    signal state_counter            : unsigned(31 downto 0);
    signal data_valid               : std_logic;
    signal data_last                : std_logic; 
    signal packet_dest              : unsigned(47 downto 0);
    signal header_buffer            : std_logic_vector((HEADER_BYTES*8)-1 downto 0);

 

    subtype byte_t is std_logic_vector(7 downto 0);

begin

    -- 3-stage pipeline shift register for the raw PHY inputs. Every clock cycle:
    process (clk, reset_n)
    begin
        if reset_n = '0' then 
            rxd_z              <= (others => (others => '0'));
	        rxdv_z             <= (others => '0');
	        first_packet_count <= (others => '0');
        elsif(rising_edge(clk)) then 
            rxd_z(0) <= RXD;
	        rxd_z(2 downto 1) <= rxd_z(1 downto 0);

	        rxdv_z(0) <= RXDV;
	        rxdv_z(2 downto 1)  <= rxdv_z(1 downto 0);

	        if (packet_done & first_packet_count < FIRST_PACKET_IGNORE) then
	            first_packet_count <= first_packet_count + 1;
            end if;
        end if;
    end process;

    -- count time spent in each state, 68 MII clocks for 42 bytes × 4 clocks/byte
    process (clk,reset_n)
    begin
        if reset_n = '0' then 
	        state_counter  <= (others => '0');
        elsif (rising_edge(clk)) then 
            if(current_state /= next_state) then 
                state_counter <= (others => '0');
            else 
                state_counter <= state_counter + 1;
            end if;
        end if;
    end process;


    -- // 3 process state machine
    -- // 1) decide which state to go into next
    -- Next-State Logic (Combinational)
    state_logic : process(clk, reset_n)
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
                when HEADER_S =>
                    if packet_done = '1' then
                        current_state <= IDLE_S;
                    elsif state_counter = HEADER_BYTES - 1 then
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
            header_buffer       <= (others => '0');
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
                header_buffer <= rxd_z & header_buffer((HEADER_BYTES*2)-1 downto 2);
            end if;

            if current_state = DATA_S then
                data_buffer <= rxd_z & data_buffer(7 downto 2);

                if state_counter(1 downto 0) = "11" then
                    if CHECK_DESTINATION = false or packet_dest = FPGA_MAC then
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

    mac_destination <= ethernet_header(MAC_DST_MSB downto MAC_DST_LSB);
    ethernet_header <=
        mac_destination &
        mac_source &
        eth_type_length &
        -- continue stacking fields
        ip_source &
        ip_destination &
        udp_port_src &
        udp_port_dest &
        udp_length &
        udp_checksum;
            
    packet_dest(47 downto 40) <= unsigned(header_buffer((HEADER_BYTES*8)-1  downto (HEADER_BYTES*8)-8));
    packet_dest(39 downto 32) <= unsigned(header_buffer((HEADER_BYTES*8)-9  downto (HEADER_BYTES*8)-16));
    packet_dest(31 downto 24) <= unsigned(header_buffer((HEADER_BYTES*8)-17 downto (HEADER_BYTES*8)-24));
    packet_dest(23 downto 16) <= unsigned(header_buffer((HEADER_BYTES*8)-25 downto (HEADER_BYTES*8)-32));
    packet_dest(15 downto 8)  <= unsigned(header_buffer((HEADER_BYTES*8)-33 downto (HEADER_BYTES*8)-40));
    packet_dest(7 downto 0)   <= unsigned(header_buffer((HEADER_BYTES*8)-41 downto (HEADER_BYTES*8)-48));

    preamble_sfd_buff_next(63 downto 62)    <= "00" when reset_n = '1' else rxd_z(2);
    preamble_sfd_buff_next(61 downto 0)     <= x"000000000" when reset_n = '1' else preamble_sfd_buff(63 downto 2);

    M_AXI_S_TVALID   <= data_valid;
    M_AXI_S_TDATA    <= data_buffer;
    M_AXI_S_TLAST    <= data_last;

end rtl;