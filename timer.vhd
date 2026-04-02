library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer_input is
    generic (
        BITS : positive := 4
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        enable      : in  std_logic;
        FINAL_VALUE : in  unsigned(BITS-1 downto 0);
        done        : out std_logic
    );
end entity timer_input;

architecture rtl of timer_input is

    signal Q_reg, Q_next : unsigned(BITS-1 downto 0);

begin

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            Q_reg <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                Q_reg <= Q_next;
            end if;
        end if;
    end process;

    -- Next state logic
    done <= '1' when Q_reg = FINAL_VALUE else '0';

    process(Q_reg, done)
    begin
        if done = '1' then
            Q_next <= (others => '0');
        else
            Q_next <= Q_reg + 1;
        end if;
    end process;

end architecture rtl;
