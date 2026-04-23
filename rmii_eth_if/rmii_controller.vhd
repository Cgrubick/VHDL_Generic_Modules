library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rmii_controller is
    port (
        CLK100MHZ         : in  std_logic;  -- 100 MHz system clock
        RESET_N     : in  std_logic;  -- active-low (CPU_RESETN)
        ETH_RXD     : in std_logic_vector(1 downto 0);
        ETH_CRSDV   : in std_logic;    
        ETH_RXERR   : in std_logic;
        
        LED16_B     : out std_logic;
        LED16_G     : out std_logic;
        LED16_R     : out std_logic;
        LED17_B     : out std_logic;
        LED17_G     : out std_logic;
        LED17_R     : out std_logic;
        DA_SDIN     : out std_logic;
        ETH_REFCLK : out std_logic;  -- 50 MHz ref clock to PHY
        ETH_RSTN    : out std_logic;  -- PHY reset, active-low
        ETH_TXD     : out std_logic_vector(1 downto 0);
        ETH_TXEN    : out std_logic
    );
end entity rmii_controller;

architecture rtl of rmii_controller is
    component clk_wiz_0
    port
     (-- Clock in ports
      -- Clock out ports
      MCLK          : out    std_logic;
      ETHCLK          : out    std_logic;
      EXT_ETHCLK          : out    std_logic;
      -- Status and control signals
      resetn             : in     std_logic;
      clk_in1           : in     std_logic
     );
    end component;


    -- 5-second inter-packet timer at 50 MHz
    signal pkt_timer   : unsigned(28 downto 0) := (others => '1');
    -- Blink counter: holds LED on ~500 ms after each packet fires
    -- 25-bit counter @ 50 MHz: 2^25 / 50e6 = 0.67 s
    signal blink_timer : unsigned(24 downto 0) := (others => '0');

    -- AXI-Stream signals to packet_tx
    signal tvalid : std_logic := '0';
    signal tdata  : std_logic_vector(7 downto 0) := (others => '0');
    signal tlast  : std_logic := '0';
    signal tready : std_logic;

    -- Byte driver state machine
    type drv_t is (IDLE, SEND);
    signal drv_state : drv_t := IDLE;
    signal byte_idx  : integer range 0 to 63 := 0;

    -- "hello clay" payload padded to 64 bytes
    type payload_t is array (0 to 63) of std_logic_vector(7 downto 0);
    constant PAYLOAD : payload_t := (
        x"68", x"65", x"6C", x"6C", x"6F",  -- h e l l o
        x"20",                                --  (space)
        x"63", x"6C", x"61", x"79",          -- c l a y
        others => x"00"                       -- zero padding to 64 bytes
    );

    component packet_tx is
        port (
            clk            : in  std_logic;
            reset_n        : in  std_logic;
            S_AXI_S_TVALID : in  std_logic;
            S_AXI_S_TDATA  : in  std_logic_vector(7 downto 0);
            S_AXI_S_TLAST  : in  std_logic;
            S_AXI_S_TREADY : out std_logic;
            ETH_TXD        : out std_logic_vector(1 downto 0);
            ETH_TXEN       : out std_logic
        );
    end component;

    COMPONENT ila_0
    PORT (
    	clk : IN STD_LOGIC;
    	probe0 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
    	probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
    	probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
    	probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
    	probe4 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
    	probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
    	probe6 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
    	probe7 : IN STD_LOGIC_VECTOR(28 DOWNTO 0);
    	probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END COMPONENT  ;

    -- Internal versions of output ports (out ports cannot be read back)
    signal eth_txd_i  : std_logic_vector(1 downto 0);
    signal eth_txen_i : std_logic;

    -- ILA helper signals
    signal ila_eth_txd   : std_logic_vector(1 downto 0);
    signal ila_eth_txen  : std_logic_vector(0 downto 0);
    signal error                : std_logic := '0'; 
    signal m_clk                : std_logic; 
    signal s_clk                : std_logic;
    signal m_clk_cnt            : unsigned(2 downto 0);

    signal right_left_sel       : std_logic;
    signal s_clk_cnt            : unsigned(7 downto 0);

    signal watchdog             : unsigned(11 downto 0); 
    signal prev_right_left_sel  : std_logic;

    signal M_AXI_S_TVALID       : std_logic;
    signal M_AXI_S_TDATA        : std_logic_vector(7 downto 0);
    signal M_AXI_S_TLAST        : std_logic;
    signal eth_clk              : std_logic;
begin

   mclk : clk_wiz_0
       port map ( 
       MCLK     => m_clk,      -- ~22 MHz
       ETHCLK   => eth_clk, --  50 MHz     
       EXT_ETHCLK => ETH_REFCLK,   -- 50 Mhz 45 degree phase shift
       resetn   => RESET_N,
       clk_in1  => CLK100MHZ
    );
    ETH_RSTN <= RESET_N;

    -- 10-second timer; fires on wrap from max to 0
    -- Initialised to all-ones so it wraps immediately on first PHY-ready clock
    process(eth_clk, reset_n)
    begin
        if reset_n = '0' then
            pkt_timer <= (others => '1');
        elsif rising_edge(eth_clk) then
            if pkt_timer = 249999999 then
                pkt_timer <= (others => '0');
            else
                pkt_timer <= pkt_timer + 1;
            end if;
        end if;
    end process;

    -- Blink latch: loads on packet fire, counts down to 0
    process(eth_clk, reset_n)
    begin
        if reset_n = '0' then
            blink_timer <= (others => '0');
        elsif rising_edge(eth_clk) then
            if pkt_timer = 0 then
                blink_timer <= (others => '1');
            elsif blink_timer /= 0 then
                blink_timer <= blink_timer - 1;
            end if;
        end if;
    end process;

    -- AXI-S byte driver
    -- Starts a new send when pkt_timer wraps to 0
    process(eth_clk, reset_n)
    begin
        if reset_n = '0' then
            drv_state <= IDLE;
            byte_idx  <= 0;
            tvalid    <= '0';
            tdata     <= (others => '0');
            tlast     <= '0';
        elsif rising_edge(eth_clk) then
            case drv_state is

                when IDLE =>
                    tvalid <= '0';
                    tlast  <= '0';
                    if pkt_timer = 0 then
                        byte_idx  <= 0;
                        drv_state <= SEND;
                    end if;

                when SEND =>
                    tvalid <= '1';
                    tdata  <= PAYLOAD(byte_idx);
                    tlast  <= '0';
                    if tready = '1' then
                        if byte_idx = 63 then
                            tvalid    <= '0';
                            drv_state <= IDLE;
                        else
                            byte_idx <= byte_idx + 1;
                        end if;
                    end if;
                    -- Must come last so it wins over the tready block above
                    if byte_idx = 63 then
                        tlast <= '1';
                    end if;

            end case;
        end if;
    end process;

    tx: packet_tx
    port map (
        clk            => eth_clk,
        reset_n        => reset_n,
        S_AXI_S_TVALID => tvalid,
        S_AXI_S_TDATA  => tdata,
        S_AXI_S_TLAST  => tlast,
        S_AXI_S_TREADY => tready,
        ETH_TXD        => eth_txd_i,
        ETH_TXEN       => eth_txen_i
    );

    ETH_TXD  <= eth_txd_i;
    ETH_TXEN <= eth_txen_i;



    -- -- ILA type casts
    -- ila_eth_txd     <= eth_txd_i;
    -- ila_eth_txen(0) <= eth_txen_i;

    -- ila : ila_0
    -- PORT MAP (
    --     clk    => eth_clk,
    --     probe0 => ila_eth_txd,                        -- ETH_TXD       [1:0]
    --     probe1 => ila_eth_txen,                       -- ETH_TXEN      [0]
    --     probe2 => (0 => tvalid),                      -- tvalid        [0]
    --     probe3 => (0 => tlast),                       -- tlast         [0]
    --     probe4 => tdata,                              -- tdata         [7:0]
    --     probe5 => (0 => tready),                      -- tready        [0]
    --     probe6 => (others => '0'),
    --     probe7 => std_logic_vector(pkt_timer),
    --     probe8 => (others => '0')
    -- );
    
        -- ERROR REPORTING RGB LEDS, GREEN - No Error, Red Error in XYZ TODO
    LED16_G <= not ETH_RXERR;
    LED16_R <= ETH_RXERR;
    
    
    LED17_G <= '0';
    LED17_R <= '0';

    LED16_B <= '0';
    LED17_B <= '1' when blink_timer /= 0 else '0';

end rtl;
