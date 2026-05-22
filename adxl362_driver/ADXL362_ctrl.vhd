-- ##Accelerometer - Constraints
--  ACL_MISO
--  ACL_MOSI
--  ACL_SCLK
--  ACL_CSN 
--  ACL_INT[1] 
--  ACL_INT[2] 

-- Targets the nexys a7 digilent board
-- For the adxl362 the part ID is = 0xF2, im using this as a BIT at the start of POR, 
-- This will confirm I have comms with the device before I read any other registers for IMU data

-- The SPI bus timing follows CPHA = CPOL = 0 per the datasheet, spi clk is 5 MHz
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adxl362_ctrl is
    port (
        clk         : in std_logic;
        rst_n       : in std_logic;
        command     : in std_logic_vector(7 downto 0); -- 00 - Idle, 0A - Write Reg, 0B - Read Reg,  0D - Read FIFO
        imu_reg     : in std_logic_vector(7 downto 0);
        ACL_INT     : in std_logic_vector(1 downto 0);
        ACL_MISO    : in std_logic;
        ACL_MOSI    : out std_logic;
        ACL_SCLK    : out std_logic; -- idles at a low level for CPHA = CPOL = 0
        ACL_CSN     : out std_logic;
        data_out    : out std_logic_vector(7 downto 0);
        pbit_fail   : out std_logic;
        pbit_done   : out std_logic
    );
end entity adxl362_ctrl;

architecture rtl of adxl362_ctrl is
    constant RD_CMD             : std_logic_vector(7 downto 0) := x"0B";
    constant WR_CMD             : std_logic_vector(7 downto 0) := x"0A";
    constant adxl362_id         : std_logic_vector(7 downto 0) := x"F2";
    -- SPI Commands
    constant write_reg          : std_logic_vector(7 downto 0) := x"0A";
    constant read_reg           : std_logic_vector(7 downto 0) := x"0B";
    constant read_fifo          : std_logic_vector(7 downto 0) := x"0D";
    -- REGISTER ADDRESSES
    constant adxl362_id_addr    : std_logic_vector(7 downto 0) := x"02"; -- PARTID register, reads back 0xF2
    constant x_axis_addr        : std_logic_vector(7 downto 0) := x"08";
    constant y_axis_addr        : std_logic_vector(7 downto 0) := x"09";
    constant z_axis_addr        : std_logic_vector(7 downto 0) := x"0A";
    constant status_addr        : std_logic_vector(7 downto 0) := x"0B";
    constant temp_l_addr        : std_logic_vector(7 downto 0) := x"14"; -- TEMP L [7:0]
    constant temp_h_addr        : std_logic_vector(7 downto 0) := x"15"; -- TEMP H [3:0]
    constant fifo_ctrl_addr     : std_logic_vector(7 downto 0) := x"28";

    -- ADXL362 Registers
    signal status_reg           : std_logic_vector(7 downto 0);
    alias err_user              : std_logic is status_reg(7); 
    alias awake                 : std_logic is status_reg(6);   
    alias inact                 : std_logic is status_reg(5);   
    alias act                   : std_logic is status_reg(4);   
    alias fifo_overflow         : std_logic is status_reg(3);   
    alias fifo_watermark        : std_logic is status_reg(2);     
    alias fifo_ready            : std_logic is status_reg(1);      
    alias data_ready            : std_logic is status_reg(0); -- cleared when a fifo read is performed 
    signal x_reg                : std_logic_vector(7 downto 0);
    signal y_reg                : std_logic_vector(7 downto 0);
    signal z_reg                : std_logic_vector(7 downto 0);
    signal temp_L_reg           : std_logic_vector(7 downto 0);
    signal temp_H_reg           : std_logic_vector(7 downto 0);

    type spi_states is (IDLE_S, BIT_WR_ADDR_S, BIT_WR_INSTR_S, BIT_RD_S, WR_REG_S, RD_REG_S);
    signal current_state      	: spi_states;
    signal prev_state           : spi_states;

    signal mosi_sreg        : std_logic_vector(7 downto 0);
    signal miso_sreg        : std_logic_vector(7 downto 0);
    signal miso_next : std_logic_vector(7 downto 0);
    signal imu_reg_d      : std_logic_vector(7 downto 0);

    signal bit_counter  : unsigned(3 downto 0);
    alias byte_done     :  std_logic is bit_counter(3);

    signal spi_clk : std_logic;
    signal spi_clk_d : std_logic;
    signal spi_clk_counter              : unsigned(4 downto 0);
    signal sclk_rise    : std_logic;  
    signal sclk_fall    : std_logic;  
    constant spi_clk_pulse    : unsigned := "10100";


    
    signal sec_wait           : unsigned(31 downto 0);
    signal sec_done           : std_logic;

begin


    process (clk, rst_n)
    begin
        if rst_n = '0' then
            sec_wait <= (others => '0');
            sec_done <= '0';
        elsif rising_edge(clk) then
            if sec_done = '0' then 
                if(sec_wait = x"FFFFFFFF") then 
                    sec_done <= '1';
                else
                    sec_wait <= sec_wait + 1;
                end if;
            end if;
        end if;
    end process;

    -- 5MHz clock, runs on falling edge of CS_N
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            spi_clk <= '0';
            spi_clk_counter <= (others => '0');
        elsif rising_edge(clk) then
            spi_clk_d <= spi_clk;
            sclk_rise <= (not spi_clk_d) and spi_clk;
            sclk_fall <= spi_clk_d and (not spi_clk);

            if(ACL_CSN = '0') then 
                spi_clk_counter <= spi_clk_counter + 1;
                if(spi_clk_counter = spi_clk_pulse) then -- 100 MHz / 20 = 5MHz
                    spi_clk <= not spi_clk;
                    spi_clk_counter <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- bit counter
    process (clk, rst_n)
    begin
        if(rst_n = '0') then 
            bit_counter <= "0001";
        elsif rising_edge(clk) then
            if current_state = IDLE_S then
              bit_counter <= "0001";
            elsif(sclk_rise = '1') then 
                if (byte_done = '1') then 
                    bit_counter <= "0001";
                else
                    bit_counter <= bit_counter + 1;
                end if;
            end if;
        end if;
    end process;

    -- SPI FSM
    process (clk, rst_n)
    begin
        if(rst_n = '0') then 
            current_state <= IDLE_S;
        elsif rising_edge(clk) then
            case current_state is
                when IDLE_S =>
                    if pbit_done = '0' and sec_done = '1' then
                        current_state <= BIT_WR_INSTR_S;
                    elsif(command = WR_CMD) then
                        current_state <= RD_REG_S;
                    elsif(command = RD_CMD) then
                        current_state <= WR_REG_S;
                    end if;
                when BIT_WR_INSTR_S =>
                    if(byte_done = '1' and sclk_rise = '1') then 
                        current_state <= BIT_WR_ADDR_S;
                    end if;
                when BIT_WR_ADDR_S =>
                    if(byte_done = '1' and sclk_rise = '1') then 
                        current_state <= BIT_RD_S;
                    end if;
                when BIT_RD_S =>
                    if (pbit_done = '1' and sclk_rise = '1') then 
                        current_state <= IDLE_S;
                    end if;
                when WR_REG_S =>
                    current_state <= RD_REG_S;
                when RD_REG_S =>
                    current_state <= IDLE_S;

                when others =>
            
            end case ;
        end if;
    end process;


    process (clk, rst_n)
    begin
        if(rst_n = '0') then
            pbit_fail   <= '1';
            pbit_done   <= '0';
        elsif rising_edge(clk) then
            if current_state = BIT_RD_S  then 
                if sclk_rise = '1' then 
                    miso_sreg <= miso_next;
                    if(miso_next = adxl362_id) then
                            pbit_fail   <= '0'; 
                    end if;
                    if(byte_done = '1' and pbit_done = '0') then
                            pbit_done   <= '1';
                        
                        
                    end if;
                end if;
            elsif current_state = RD_REG_S then
                if sclk_rise = '1' then 
                    miso_sreg <= miso_sreg(6 downto 0) & ACL_MISO; -- msb shifted in first
                end if;
            elsif current_state = IDLE_S then
                miso_sreg <= (others => '0');
            end if;
        end if;
    end process;

    process (clk, rst_n)
    begin
        if(rst_n = '0') then
            mosi_sreg <= (others => '0');
            imu_reg_d <= (others => '0');
        elsif rising_edge(clk) then
            -- Shift register input for MOSI
            prev_state <= current_state;
            if current_state /= prev_state then
                case current_state is
                    when BIT_WR_INSTR_S => mosi_sreg <= RD_CMD;
                    when BIT_WR_ADDR_S  => mosi_sreg <= adxl362_id_addr;
                    when others         => 
                end case;
            elsif spi_clk_d = '1' and spi_clk = '0' then  -- falling edge
                if (current_state = BIT_WR_INSTR_S or current_state = BIT_WR_ADDR_S) and bit_counter /= 1 then
                    mosi_sreg <= mosi_sreg(6 downto 0) & '0';
                end if;
            end if;

        end if;
    end process;

 miso_next <= miso_sreg(6 downto 0) & ACL_MISO;    
    -- Output logic
    ACL_MOSI <= mosi_sreg(7);
	ACL_CSN <= '0' when current_state = BIT_WR_INSTR_S or current_state = BIT_WR_ADDR_S or 
                        current_state = BIT_RD_S       or current_state = WR_REG_S      or 
                        current_state = RD_REG_S else '1';
    ACL_SCLK <= spi_clk;
    data_out <= miso_sreg;

end architecture;