library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ip_defs_pkg.all;


entity packet_tx is
	port (
		clk             : in std_logic;
		reset_n         : in std_logic;
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
        	clk     : in  std_logic;
        	reset_n : in  std_logic;                      
        	data_in : in  std_logic_vector(1 downto 0);
        	crc_en  : in  std_logic;
        	crc_out : out std_logic_vector(31 downto 0)
		);
	end component;
	
	component async_fifo is
		generic (
            DATA_WIDTH : positive := 8;
            ADDR_WIDTH : positive := 4   -- depth = 2**ADDR_WIDTH
    	);
		port (
            -- Write side
            wr_clk   : in  std_logic;
            wr_rst_n : in  std_logic;
            wr_en    : in  std_logic;
            wr_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            wr_full         : out std_logic;
            wr_afull  : out std_logic;
            -- Read side
            rd_clk   : in  std_logic;
            rd_rst_n : in  std_logic;
            rd_en    : in  std_logic;
            rd_data         : out std_logic_vector(DATA_WIDTH-1 downto 0);
            rd_empty        : out std_logic;
            rd_aempty : out std_logic
		);
	end component;

	constant PAYLOAD_BYTE_COUNT		: integer := 64;
	constant HEADER_BYTES           : integer := 42;
	constant ETH_HEADER_BITS        : integer := HEADER_BYTES * 8;  -- 336 bits
	constant PREAMBLE : std_logic_vector(55 downto 0) := x"55555555555555"; 
	constant FIFO_WIDTH				: positive := 8;
	constant FIFO_ADDR				: positive := 5;

	type eth_states is (IDLE_S, PREAMBLE_S, SFD_S, HEADER_S, DATA_S, FCS_S, WAIT_S);
	signal current_state      : eth_states;

	signal fcs          	: std_logic_vector(31 downto 0);
	signal crc_en           	: std_logic;
	signal crc_rst_n				: std_logic;

	signal tx_start  	: std_logic;
	signal preamble_done    	: std_logic;
	signal sfd_done				: std_logic;
	signal header_done			: std_logic;
	signal data_done			: std_logic;

	signal eth_header	: std_logic_vector(ETH_HEADER_BITS-1 downto 0);
	signal mac_destination    	: std_logic_vector(47 downto 0) := HOST_MAC;
	signal mac_source         	: std_logic_vector(47 downto 0) := FPGA_MAC;
	signal eth_type_length    	: std_logic_vector(15 downto 0) := x"0008";  -- 0x0800 IPv4
	signal ip_source          	: std_logic_vector(31 downto 0) := FPGA_IP;
	signal ip_destination     	: std_logic_vector(31 downto 0) := HOST_IP;
	signal udp_port_src       	: std_logic_vector(15 downto 0) := FPGA_PORT;
	signal udp_port_dest      	: std_logic_vector(15 downto 0) := HOST_PORT;
	signal udp_length         	: std_logic_vector(15 downto 0) := x"4800";  -- 0x0048 = 72 (8 hdr + 64 payload)
	signal udp_checksum       	: std_logic_vector(15 downto 0) := x"0000";  -- disabled
	signal ip_header_checksum 	: std_logic_vector(15 downto 0) := x"F125";  -- 0x25F1
	signal protocol           	: std_logic_vector(7  downto 0) := x"11";    -- UDP
	signal ttl                	: std_logic_vector(7  downto 0) := x"40";    -- 64 hops
	signal flags_frag         	: std_logic_vector(15 downto 0) := x"0040";  -- 0x4000 don't fragment
	signal identification     	: std_logic_vector(15 downto 0) := x"0000";
	signal total_length       	: std_logic_vector(15 downto 0) := x"5C00";  -- 0x005C = 92 (20+8+64)
	signal dscp_ecn           	: std_logic_vector(7  downto 0) := x"00";    -- best effort
	signal version_ihl        	: std_logic_vector(7  downto 0) := x"45";    -- IPv4, 20-byte header

	signal txdata				: std_logic_vector(1 downto 0);

	signal packet_count			: unsigned(15 downto 0);

	-- FIFO Signals
	signal wr_rst_n        	: std_logic;
	signal wr_en           	: std_logic;
	signal wr_data         	: std_logic_vector(FIFO_WIDTH - 1 downto 0);
	signal wr_full         	: std_logic;
	signal wr_afull  		: std_logic;
	signal rd_rst_n        	: std_logic;
	signal rd_en           	: std_logic;
	signal rd_data         	: std_logic_vector(FIFO_WIDTH - 1 downto 0);
	signal rd_empty        	: std_logic;
	signal rd_aempty 		: std_logic;

	signal fcs_done      	: std_logic;
	signal state_counter 	: unsigned(3 downto 0) := (others => '0');

	signal rd_data_reg 			 : std_logic_vector(FIFO_WIDTH - 1 downto 0); 

	signal preamble_buffer			: std_logic_vector(55 downto 0);
	signal sfd_buffer				: std_logic_vector(7 downto 0);
	signal header_buffer 			: std_logic_vector(ETH_HEADER_BITS-1 downto 0);
	signal rd_data_buffer				: std_logic_vector(FIFO_WIDTH - 1 downto 0);
	signal fcs_buffer					: std_logic_vector(31 downto 0);

begin

	crc: crc_32
	port map (
		clk    	=> clk,
		reset_n => reset_n AND crc_rst_n,
		data_in => txdata,
		crc_en  => crc_en,
		crc_out => fcs
	);


	wr_rst_n <= reset_n;
	rd_rst_n	<= reset_n;
	fifo: async_fifo
		generic map (
			DATA_WIDTH => FIFO_WIDTH,
       		ADDR_WIDTH => FIFO_ADDR
		)
		port map (
        	wr_clk          => clk, 
        	wr_rst_n        => wr_rst_n,
        	wr_en           => wr_en,   
        	wr_data         => wr_data, 
        	wr_full         => wr_full,
        	wr_afull  		=> wr_afull,
        	-- Read side
        	rd_clk          => clk,  
        	rd_rst_n        => rd_rst_n,
        	rd_en           => rd_en,   
        	rd_data         => rd_data,
        	rd_empty        => rd_empty,
        	rd_aempty 		=> rd_aempty
		);

	-- Packet FSM
	process (clk, reset_n)
	begin
		if reset_n = '0' then
			crc_en        <= '0';
			state_counter <= (others => '0');
			current_state <= IDLE_S;
					crc_rst_n <= '1';
		elsif rising_edge(clk) then
			state_counter <= (others => '0');
			case current_state is
				when IDLE_S =>	
					crc_en <= '0';
					crc_rst_n <= '0';
					if tx_start = '1' then
						current_state <= PREAMBLE_S;
					end if;
				when PREAMBLE_S =>
					crc_rst_n <= '1';
					crc_en <= '0';
					if preamble_done = '1' then
						current_state <= SFD_S;
					end if;
				when SFD_S =>
					crc_rst_n <= '1';
					crc_en <= '0';
					if sfd_done = '1' then
						current_state <= HEADER_S;
					end if;
				when HEADER_S =>
					crc_en <= '1';
					if header_done = '1' then
						current_state <= DATA_S;
					end if;
				when DATA_S =>
					crc_en <= '1';
					if data_done = '1' then
						current_state <= FCS_S;
					end if;
				when FCS_S =>
					crc_en        <= '0';
					state_counter <= state_counter + 1;
					if fcs_done = '1' then
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
			if current_state = PREAMBLE_S OR current_state = SFD_S OR current_state = HEADER_S OR current_state = DATA_S OR current_state = FCS_S then
				packet_count	<= packet_count + 1;
			else 
				packet_count <= (others => '0');
			end if;
		end if;
	end process;

	-- Ethernet Frame without preamble and FCS.
	-- Concatenation is REVERSED from wire order: shift_right transmits low bits first,
	-- so the rightmost (lowest) field is transmitted first on the wire.
	-- Wire order: mac_destination, mac_source, eth_type, IP header, UDP header.
	eth_header <= udp_checksum & udp_length & udp_port_dest & udp_port_src
				& ip_destination & ip_source & ip_header_checksum & protocol & ttl
				& flags_frag & identification & total_length & dscp_ecn & version_ihl
				& eth_type_length & mac_source & mac_destination;


	-- Buffering
	process (clk)
	begin
		if(reset_n  = '0') then

			rd_en                 <= '0';  -- default: deassert every clock
		elsif rising_edge(clk) then
			
			rd_en                 <= '0';  -- default: deassert every clock
			case current_state is
				when IDLE_S 	=>
					header_buffer <= eth_header;
					sfd_buffer      <= x"D5";
					preamble_buffer <= PREAMBLE;
				when PREAMBLE_S =>
					preamble_buffer <= std_logic_vector(shift_right(unsigned(preamble_buffer), 2));
				when HEADER_S 	=>
					header_buffer <= std_logic_vector(shift_right(unsigned(header_buffer), 2));
					if header_done = '1' then
      					rd_data_buffer <= rd_data;
      					rd_en <= '1';
  					end if;
				when DATA_S 	=>
					if data_done = '1' then
      					fcs_buffer <= fcs;
  					end if;
					if packet_count(1 downto 0) = "11" and data_done = '0' then
						rd_en <= '1';  
      		    	    rd_data_buffer <= rd_data;  
					else
						rd_data_buffer <= std_logic_vector(shift_right(unsigned(rd_data_buffer), 2));
  			    	end if;
				when FCS_S 		=>
					fcs_buffer <= std_logic_vector(shift_right(unsigned(fcs_buffer), 2));
				when others =>
			end case;
		end if;
	end process;
	-- TX Shift Register
	process (clk)
	begin
		if reset_n = '0' then
			txdata                  <= (others => '0');
		elsif rising_edge(clk) then
			case current_state is
				when IDLE_S 	=>
					txdata                  <= (others => '0');
				when PREAMBLE_S =>
					txdata 		<= preamble_buffer(1 downto 0);
				when SFD_S		=>
					txdata 			<= sfd_buffer(1 downto 0);
				when HEADER_S 	=>
					txdata 		<= header_buffer(1 downto 0);
				when DATA_S 	=>
					txdata      <= rd_data_buffer(1 downto 0);
				when FCS_S 		=>
					txdata      <= fcs_buffer(1 downto 0);
				when others =>
			end case;
		end if;
	end process;

	tx_start        <= S_AXI_S_TLAST;
	wr_en           <= S_AXI_S_TVALID and not wr_full;
	wr_data         <= S_AXI_S_TDATA;
	data_done 	    <= '1' when rd_empty = '1' else '0';
	fcs_done        <= '1' when current_state = FCS_S 		and state_counter = 15 else '0';
	header_done		<= '1' when current_state = HEADER_S   	and packet_count = 200 else '0';
	preamble_done 	<= '1' when current_state = PREAMBLE_S 	and packet_count = 28  else '0';	
	sfd_done 		<= '1' when current_state = SFD_S 		and packet_count = 32  else '0';
	ETH_TXD		    <= txdata;
  	ETH_TXEN        <= '1' when current_state = PREAMBLE_S or current_state = HEADER_S or current_state = SFD_S
  	                   	or current_state = DATA_S or current_state = FCS_S
  	                    else '0';
	S_AXI_S_TREADY <= not wr_full;

end rtl;