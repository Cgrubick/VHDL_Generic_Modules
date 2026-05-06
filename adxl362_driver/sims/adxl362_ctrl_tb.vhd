library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adxl362_ctrl_tb is
end entity;

architecture sim of adxl362_ctrl_tb is

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal command  : std_logic_vector(1 downto 0) := "00";
    signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
    signal ACL_INT  : std_logic_vector(1 downto 0) := "00";
    signal ACL_MOSI : std_logic := '0';
    signal ACL_MISO : std_logic;
    signal ACL_SCLK : std_logic;
    signal ACL_CSN  : std_logic;
    signal data_out : std_logic_vector(7 downto 0);

begin

    DUT : entity work.adxl362_ctrl
        port map (
            clk      => clk,
            rst_n    => rst_n,
            command  => command,
            data_in  => data_in,
            ACL_INT  => ACL_INT,
            ACL_MOSI => ACL_MOSI,
            ACL_MISO => ACL_MISO,
            ACL_SCLK => ACL_SCLK,
            ACL_CSN  => ACL_CSN,
            data_out => data_out
        );

    -- Clock
    clk <= not clk after CLK_PERIOD / 2;

    -- Stimulus
    process
    begin
        rst_n   <= '0';
        command <= "00";
        data_in <= (others => '0');
        wait for 5 * CLK_PERIOD;

        rst_n <= '1';
        wait for 5 * CLK_PERIOD;

        -- issue a read command
        command <= "10";
        data_in <= x"01";
        wait for 2 * CLK_PERIOD;
        command <= "00";

        wait for 20 * CLK_PERIOD;

        -- issue a write command
        command <= "01";
        data_in <= x"A5";
        wait for 2 * CLK_PERIOD;
        command <= "00";

        wait for 50 * CLK_PERIOD;

        report "sim done" severity note;
        wait;
    end process;

end architecture;
