library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity baud_gen is 
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
end baud_gen;

architecture rtl of baud_gen is
    constant MAX_RATE   : integer := ((CLOCK_RATE) / (2 * BAUD_RATE * 16)) - 1;
    signal counter      : integer := 0;
    signal tick_reg     : std_logic;
begin
  process(clk, reset_n) begin
    if(reset_n = '0') then

    end if;

    if(enable_i = '1') then
        if(rising_edge(clk)) then
            if(counter = MAX_RATE) then 
                tick_reg <= '1';
            else
                counter <= counter + 1;
            end if;
        end if;
    end if;
  end process;

  tick_o <= tick_reg;

end rtl;