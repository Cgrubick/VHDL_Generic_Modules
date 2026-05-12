library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adxl362_ctrl_tb is
end entity;

architecture sim of adxl362_ctrl_tb is

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal command  : std_logic_vector(7 downto 0) := x"00";
    signal imu_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal ACL_INT  : std_logic_vector(1 downto 0) := "00";
    signal ACL_MOSI : std_logic := '0';
    signal ACL_MISO : std_logic := '0';
    signal ACL_SCLK : std_logic;
    signal ACL_CSN  : std_logic;
    signal data_out : std_logic_vector(7 downto 0);
    -- ADXL362 register address map (for the slave model)
    constant adxl362_id_addr : std_logic_vector(7 downto 0) := x"01";
    constant adxl362_id      : std_logic_vector(7 downto 0) := x"F2";
    constant status_addr     : std_logic_vector(7 downto 0) := x"0B";
    constant status_val      : std_logic_vector(7 downto 0) := x"40"; -- awake
    constant x_axis_addr     : std_logic_vector(7 downto 0) := x"08";
    constant x_axis_val      : std_logic_vector(7 downto 0) := x"11";
    constant y_axis_addr     : std_logic_vector(7 downto 0) := x"09";
    constant y_axis_val      : std_logic_vector(7 downto 0) := x"22";
    constant z_axis_addr     : std_logic_vector(7 downto 0) := x"0A";
    constant z_axis_val      : std_logic_vector(7 downto 0) := x"33";
    constant fifo_ctrl_addr  : std_logic_vector(7 downto 0) := x"28";

    constant read_reg_cmd  : std_logic_vector(7 downto 0) := x"0B";
    constant write_reg_cmd : std_logic_vector(7 downto 0) := x"0A";

    -- Slave model: shift in cmd byte then addr byte from MOSI; if the address
    -- matches a known register, shift its value out on MISO. Otherwise do nothing.
    procedure send_miso_byte (signal mosi : in  std_logic;
                              signal miso : out std_logic;
                              signal sclk : in  std_logic) is
        variable cmd  : std_logic_vector(7 downto 0);
        variable addr : std_logic_vector(7 downto 0);
        variable data : std_logic_vector(7 downto 0);
        variable hit  : boolean := true;
    begin
        for i in 7 downto 0 loop
            wait until rising_edge(sclk);
            cmd(i) := mosi;
        end loop;

        for i in 7 downto 0 loop
            wait until rising_edge(sclk);
            addr(i) := mosi;
        end loop;

        if cmd /= read_reg_cmd then
            return;
        end if;

        case addr is
            when adxl362_id_addr => data := adxl362_id;
            when status_addr     => data := status_val;
            when x_axis_addr     => data := x_axis_val;
            when y_axis_addr     => data := y_axis_val;
            when z_axis_addr     => data := z_axis_val;
            when others          => hit  := false;
        end case;

        if not hit then
            return;
        end if;

        for i in 7 downto 0 loop
            wait until falling_edge(sclk);
            miso <= data(i);
        end loop;
    end procedure;

begin

    DUT : entity work.adxl362_ctrl
        port map (
            clk      => clk,
            rst_n    => rst_n,
            command  => command,
            imu_reg  => imu_reg,
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

        -- REGISTER READ GOES
        -- MOSI: ------ INSTRUCTION [7:0] - ADDR [7:0] ----------------
        -- MISO: --------------------------------------- DATA OUT [7:0]
        rst_n   <= '0';
        command <= x"00";
        wait for 5 * CLK_PERIOD;

        rst_n <= '1';
        wait for 5 * CLK_PERIOD;

        -- issue a read command
        command <= x"0A";
        imu_reg <= adxl362_id_addr;
        send_miso_byte(ACL_MOSI, ACL_MISO, ACL_SCLK);
        wait for 2 * CLK_PERIOD;
        command <= x"00";

        wait for 20 * CLK_PERIOD;

        -- -- issue a write command
        -- command <= "01";
        -- imu_reg <= fifo_ctrl_addr;
        -- wait for 2 * CLK_PERIOD;
        -- command <= "00";

        wait for 50 * CLK_PERIOD;

        report "sim done" severity note;
        wait;
    end process;

end architecture;
