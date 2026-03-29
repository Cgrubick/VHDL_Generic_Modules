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

	constant PAYLOAD_BYTE_COUNT		: integer := 64;
	constant MII_WIDTH              : integer := 2;
	constant FIRST_PACKET_IGNORE    : integer := 0;
	constant HEADER_BYTES           : integer := 42;
	constant ETH_HEADER_BITS        : integer := HEADER_BYTES * 8;  -- 336 bits
	constant SFD_PREAMBLE           : std_logic_vector(63 downto 0) := x"d555555555555555";

	type eth_states is (IDLE_S, PREAMBLE_S, HEADER_S, DATA_S, FCS_S, WAIT_S);
	signal current_state      : eth_states;
	signal state_counter      : unsigned(31 downto 0);


	-- FIFO
	signal fifo_full        	: std_logic;
	signal fifo_empty       	: std_logic;
	signal fifo_count       	: unsigned(11 downto 0);
	signal fifo_data_o      	: std_logic_vector(7 downto 0);

	signal crc_data         	: std_logic_vector(1 downto 0);
	signal crc_in           	: std_logic_vector(31 downto 0);
	signal crc_out          	: std_logic_vector(31 downto 0);
	signal crc_en           	: std_logic;

	signal packet_assemble  	: std_logic;
	signal preamble_done    	: std_logic;
	signal header_done			: std_logic;
	signal data_done			: std_logic;

	signal eth_packet_header	: std_logic_vector(ETH_HEADER_BITS-1 downto 0);
	signal mac_destination    	: std_logic_vector(47 downto 0);
	signal mac_source         	: std_logic_vector(47 downto 0);
	signal eth_type_length    	: std_logic_vector(15 downto 0);
	signal ip_source          	: std_logic_vector(31 downto 0);
	signal ip_destination     	: std_logic_vector(31 downto 0);
	signal udp_port_src       	: std_logic_vector(15 downto 0);
	signal udp_port_dest      	: std_logic_vector(15 downto 0);
	signal udp_length         	: std_logic_vector(15 downto 0);
	signal udp_checksum       	: std_logic_vector(15 downto 0);
	signal ip_header_checksum 	: std_logic_vector(15 downto 0);
	signal protocol           	: std_logic_vector(7  downto 0);
	signal ttl                	: std_logic_vector(7  downto 0);
	signal flags_frag         	: std_logic_vector(15 downto 0);
	signal identification     	: std_logic_vector(15 downto 0);
	signal total_length       	: std_logic_vector(15 downto 0);
	signal dscp_ecn           	: std_logic_vector(7  downto 0);
	signal version_ihl        	: std_logic_vector(7  downto 0);
	signal data_buffer			: std_logic_vector((PAYLOAD_BYTE_COUNT-1)/8 downto 0); 

	signal txdata				: std_logic_vector(1 downto 0);
	signal txvalid				: std_logic;

	signal packet_count			: unsigned(15 downto 0);

begin

	crc: crc_32
	port map (
		crc_in 	=> crc_in,
		crc_en  => crc_en,
		data   	=> crc_data,
		crc_out => crc_out
	);

	-- data_fifo : fifo
	-- port map(

	-- );

	-- Packet FSM

	process (clk, reset_n)
	begin
		if reset_n = '0' then
			crc_en <= '0';
			current_state <= IDLE_S; 
		elsif rising_edge(clk) then
			case current_state is
				when IDLE_S =>	
					crc_en <= '0';
					if packet_assemble = '1' then
						current_state <= PREAMBLE_S;
					end if;
				when PREAMBLE_S =>
					if preamble_done = '1' then
						current_state <= HEADER_S;
					end if;
				when HEADER_S =>
					crc_en <= '1';
					if header_done = '1' then
						current_state <= DATA_S;
					end if;
				when DATA_S =>	
					if data_done = '1' then 
						current_state <= FCS_S;
					end if;
				when FCS_S =>
					if data_done = '1' then 
						current_state <= WAIT_S;
					end if;
				when WAIT_S => -- TODO not necessary?
					crc_en <= '0';
					current_state <= IDLE_S;
				when others => current_state <= IDLE_S;
			end case;
		end if;
	end process;

	-- Packet index count
	process (clk)
	begin
		if reset_n = '0' then
			packet_count <= (others => '0');
		elsif rising_edge(clk) then
			if current_state = PREAMBLE_S OR current_state = DATA_S OR current_state = PREAMBLE_S OR current_state = FCS_S then
				packet_count	<= packet_count + 1;
			else 
				packet_count <= (others => '0');
			end if;
		end if;
	end process;

	-- Ethernet Frame without preamble and FCS 
	eth_packet_header <= mac_destination & mac_source & eth_type_length & version_ihl & dscp_ecn
				& total_length & identification & flags_frag & ttl & protocol & ip_header_checksum
				& ip_source & ip_destination & udp_port_src & udp_port_dest & udp_length & udp_checksum;
	-- TX Shift Register
	process (clk)
	begin
		if reset_n = '0' then
			txdata <= (others => '0');
		elsif rising_edge(clk) then
			if current_state = PREAMBLE_S then
				txdata <= SFD_PREAMBLE(1 downto 0);
			elsif(current_state = HEADER_S) then 
				txdata <= eth_packet_header(1 downto 0);
			elsif current_state = DATA_S then 
				txdata <= data_buffer(1 downto 0);
			elsif current_state = FCS_S then
				txdata <= crc_out(1 downto 0);
			end if;
		end if;
	end process;
	
	
	packet_assemble <= fifo_full;

	ETH_TXD		<= txdata;
	ETH_TXEN	<= txvalid;


	S_AXI_S_TREADY <= not fifo_full;

end rtl;