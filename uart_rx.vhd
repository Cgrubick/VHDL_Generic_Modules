library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    port( 
        clk             : in std_logic;
        reset_n         : in std_logic;
        data_i          : in std_logic;
        data_ready_o    : out std_logic;
        data_o          : out std_logic_vector(7 downto 0)
    );

end uart_rx;

architecture rtl of uart_rx is
    component baud_gen 
        generic (
            CLOCK_RATE  : integer := 100000000;
            BAUD_RATE   : integer := 9600
        );
        port (
            clk         : in std_logic;
            reset_n     : in std_logic;
            enable_i    : in std_logic;
            sel_i       : in std_logic_vector(1 downto 0);
            tick_o      : out std_logic 
        );
    end component;

    type uart_rx_states is (Init_S, Start_S, Data_S, Stop_S);
    signal uart_rx_state    : uart_rx_states;
    signal data_reg         : std_logic_vector(7 downto 0) := (others => '0');
    signal data_ready_reg   : std_logic;
begin
    
  process(clk, reset_n) begin
    if(reset_n = '0') then
        uart_rx_state   <= Init_S;
        data_o          <= (others => '0');
        data_ready_o    <= '0';
    end if;

    if(rising_edge(clk)) then
        case uart_rx_state is
            when Init_S =>
                uart_rx_state <= Start_S;
            when Start_S =>
                uart_rx_state <= Data_S;
            when Data_S =>
                uart_rx_state <= Stop_S;
            when Stop_S =>
                uart_rx_state <= Init_S;
            when others =>
        end case;
    end if;
  end process;

  data_o        <= data_reg;
  data_ready_o  <= data_ready_reg;
  
end rtl;