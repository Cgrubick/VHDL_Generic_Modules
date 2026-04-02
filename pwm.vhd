library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm is
    generic (
        R          : positive := 8;
        TIMER_BITS : positive := 15
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        duty        : in  unsigned(R downto 0);
        FINAL_VALUE : in  unsigned(TIMER_BITS-1 downto 0);
        pwm_out     : out std_logic
    );
end entity pwm;

architecture rtl of pwm is

    component timer_input is
        generic (
            BITS : positive
        );
        port (
            clk         : in  std_logic;
            rst_n       : in  std_logic;
            enable      : in  std_logic;
            FINAL_VALUE : in  unsigned(BITS-1 downto 0);
            done        : out std_logic
        );
    end component;

    signal Q_reg, Q_next : unsigned(R-1 downto 0);
    signal d_reg, d_next : std_logic;
    signal tick          : std_logic;

begin

    -- Up Counter
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            Q_reg <= (others => '0');
            d_reg <= '0';
        elsif rising_edge(clk) then
            if tick = '1' then
                Q_reg <= Q_next;
                d_reg <= d_next;
            end if;
        end if;
    end process;

    -- Next state logic
    process(Q_reg, duty)
    begin
        Q_next <= Q_reg + 1;
        if Q_reg < duty then
            d_next <= '1';
        else
            d_next <= '0';
        end if;
    end process;

    pwm_out <= d_reg;

    -- Prescaler Timer
    timer0 : timer_input
        generic map (
            BITS => TIMER_BITS
        )
        port map (
            clk         => clk,
            rst_n       => rst_n,
            enable      => '1',
            FINAL_VALUE => FINAL_VALUE,
            done        => tick
        );

end architecture rtl;
