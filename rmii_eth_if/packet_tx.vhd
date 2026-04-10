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
        wr_full  : out std_logic;

        -- Read side
        rd_clk   : in  std_logic;
        rd_rst_n : in  std_logic;
        rd_en    : in  std_logic;
        rd_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        rd_empty : out std_logic
		);
	end component;

	constant PAYLOAD_BYTE_COUNT		: integer := 64;
	constant MII_WIDTH              : integer := 2;
	constant FIRST_PACKET_IGNORE    : integer := 0;
	constant HEADER_BYTES           : integer := 42;
	constant ETH_HEADER_BITS        : integer := HEADER_BYTES * 8;  -- 336 bits
	signal SFD_PREAMBLE           : std_logic_vector(63 downto 0) := x"d555555555555555";
	constant FIFO_WIDTH				: positive := 8;
	constant FIFO_ADDR				: positive := 5;

	type eth_states is (IDLE_S, PREAMBLE_S, HEADER_S, DATA_S, FCS_S, WAIT_S);
	signal current_state      : eth_states;
	signal state_counter      : unsigned(31 downto 0);

	signal crc_data         	: std_logic_vector(1 downto 0);
	signal crc_in           	: std_logic_vector(31 downto 0);
	signal crc_out          	: std_logic_vector(31 downto 0);
	signal crc_en           	: std_logic;

	signal tx_start  	: std_logic;
	signal preamble_done    	: std_logic;
	signal header_done			: std_logic;
	signal data_done			: std_logic;

	
	signal eth_packet_header	: std_logic_vector(ETH_HEADER_BITS-1 downto 0);
	signal mac_destination    	: std_logic_vector(47 downto 0) := HOST_MAC;
	signal mac_source         	: std_logic_vector(47 downto 0) := FPGA_MAC;
	signal eth_type_length    	: std_logic_vector(15 downto 0) := x"0800";  -- IPv4
	signal ip_source          	: std_logic_vector(31 downto 0) := FPGA_IP;
	signal ip_destination     	: std_logic_vector(31 downto 0) := HOST_IP;
	signal udp_port_src       	: std_logic_vector(15 downto 0) := FPGA_PORT;
	signal udp_port_dest      	: std_logic_vector(15 downto 0) := HOST_PORT;
	signal udp_length         	: std_logic_vector(15 downto 0) := x"0048";  -- 8 (udp header) + 64 (payload) = 72
	signal udp_checksum       	: std_logic_vector(15 downto 0) := x"0000";  -- checksum disabled (valid in UDP)
	signal ip_header_checksum 	: std_logic_vector(15 downto 0) := x"0000";  -- compute offline once header fields are fixed
	signal protocol           	: std_logic_vector(7  downto 0) := x"11";    -- UDP
	signal ttl                	: std_logic_vector(7  downto 0) := x"40";    -- 64 hops
	signal flags_frag         	: std_logic_vector(15 downto 0) := x"4000";  -- don't fragment
	signal identification     	: std_logic_vector(15 downto 0) := x"0000";
	signal total_length       	: std_logic_vector(15 downto 0) := x"005c";  -- 20 (ip) + 8 (udp) + 64 (payload) = 92
	signal dscp_ecn           	: std_logic_vector(7  downto 0) := x"00";    -- best effort
	signal version_ihl        	: std_logic_vector(7  downto 0) := x"45";    -- IPv4, 20-byte header

	signal txdata				: std_logic_vector(1 downto 0);
	signal txvalid				: std_logic;

	signal packet_count			: unsigned(15 downto 0);

	-- FIFO Signals
	signal wr_rst_n : std_logic; 
	signal wr_en    : std_logic; 
	signal wr_data  : std_logic_vector(FIFO_WIDTH - 1 downto 0);
	signal wr_full  : std_logic; 
	signal rd_rst_n : std_logic; 
	signal rd_en    : std_logic; 
	signal rd_data  : std_logic_vector(FIFO_WIDTH - 1 downto 0); 
	signal rd_empty : std_logic; 


	signal crc_out_reg 			 : std_logic_vector(31 downto 0);
	signal eth_packet_header_reg : std_logic_vector(ETH_HEADER_BITS-1 downto 0);	
	signal rd_data_reg 			 : std_logic_vector(FIFO_WIDTH - 1 downto 0); 

begin

	crc: crc_32
	port map (
		crc_in 	=> crc_in,
		crc_en  => crc_en,
		data   	=> txdata,
		crc_out => crc_out
	);


	wr_rst_n <= reset_n;
	rd_rst_n	<= reset_n;
	fifo: async_fifo
		generic map (
			DATA_WIDTH => FIFO_WIDTH,
       		ADDR_WIDTH => FIFO_ADDR
		)
		port map (
        	wr_clk   => clk, 
        	wr_rst_n => wr_rst_n,
        	wr_en    => wr_en,   
        	wr_data  => wr_data, 
        	wr_full  => wr_full, 
        	-- Read side
        	rd_clk   => clk,  
        	rd_rst_n => rd_rst_n,
        	rd_en    => rd_en,   
        	rd_data  => rd_data, 
        	rd_empty => rd_empty
		);

	-- Packet FSM
	process (clk, reset_n)
	begin
		if reset_n = '0' then
			crc_en <= '0';
			rd_en	<= '0';
			current_state <= IDLE_S; 
		elsif rising_edge(clk) then
			case current_state is
				when IDLE_S =>	
					crc_en <= '0';
					if tx_start = '1' then
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
					if(packet_count(1 downto 0) = "10") then 
						rd_en <= '1';
					end if;
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
			if current_state = PREAMBLE_S OR current_state = HEADER_S OR current_state = DATA_S OR current_state = FCS_S then
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
			crc_out_reg <= (others => '0');			
			eth_packet_header_reg 	<= (others => '0');
			rd_data_reg 	<= (others => '0');		
			crc_in <= x"FFFFFFFF";
		elsif rising_edge(clk) then
			crc_out_reg 			<= crc_out;
			eth_packet_header_reg 	<= eth_packet_header;
			rd_data_reg 			<= rd_data;
			if crc_en = '1' then
          crc_in <= crc_out;  -- feedback for iterative computation
      end if;
			if current_state = PREAMBLE_S then
				txdata <= SFD_PREAMBLE(1 downto 0);
				SFD_PREAMBLE <= std_logic_vector(shift_right(unsigned(SFD_PREAMBLE), 2)); 
			elsif(current_state = HEADER_S) then 
				txdata <= eth_packet_header_reg(1 downto 0);
				eth_packet_header_reg <= std_logic_vector(shift_right(unsigned(eth_packet_header_reg), 2));
			elsif current_state = DATA_S then 
				txdata <= rd_data_reg(1 downto 0);
				rd_data_reg <= std_logic_vector(shift_right(unsigned(rd_data_reg), 2));
				if packet_count(1 downto 0) = "11" then
      				rd_data_reg <= rd_data;  -- overrides shift, loads next byte
  				end if;
			elsif current_state = FCS_S then
				txdata <= crc_out_reg(1 downto 0);
				crc_out_reg <= std_logic_vector(shift_right(unsigned(crc_out_reg), 2));
			end if;
		end if;
	end process;


 	
	
	tx_start <= S_AXI_S_TLAST;

	ETH_TXD		<= txdata;
  	ETH_TXEN <= '1' when current_state = PREAMBLE_S or current_state = HEADER_S
  	                  or current_state = DATA_S     or current_state = FCS_S
  	            else '0';
	
	wr_en <= S_AXI_S_TVALID and not wr_full;
	wr_data <= S_AXI_S_TDATA;

 
	data_done 	    <= '1' when rd_empty = '1' else '0';
	header_done		<= '1' when current_state = HEADER_S   and packet_count = 167 else '0'; 
	preamble_done 	<= '1' when current_state = PREAMBLE_S and packet_count = 31 else '0';

	S_AXI_S_TREADY <= not wr_full;

end rtl;