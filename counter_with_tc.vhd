library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity counter_with_tc is
    port (
        clk         : in std_logic;
        rst_n       : in std_logic;
        usec_pulse  : out std_logic
    );
end entity;

architecture rtl of counter_with_tc is
    -- For a 100 MHz clock to generate a 1 us pulse
    --(1 microsecond) / (10 nanoseconds) = 100 counts
    -- to achieve 100 counts we need a vector counter with a high bit set as the terminal count
    -- 80h = 128 decimal, so we do 128 - x = 100, x = 28 or 1Ch, this is our init value

    signal usec_count   : unsigned(7 downto 0);
    constant usec_Init  : unsigned(7 downto 0) := x"1C";
    alias usec_tc      : std_logic is usec_count(7);


begin

    process (clk)
    begin
        if rising_edge(clk) then
            if (rst_n = '1' or  usec_tc = '1')then
                usec_count <= usec_Init;
            else
                usec_count <= usec_count + 1;
            end if;
        end if;
    end process;

    usec_pulse <= usec_tc;
end rtl;