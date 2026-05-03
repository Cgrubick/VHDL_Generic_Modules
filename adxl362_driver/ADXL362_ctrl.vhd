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
        ACL_INT     : in std_logic_vector(1 downto 0);
        ACL_MOSI    : in std_logic;
        ACL_MISO    : out std_logic;
        ACL_SCLK    : out std_logic;
        ACL_CSN     : out std_logic
    );
end entity adxl362_ctrl;

architecture rtl of adxl362_ctrl is
    constant adxl362_id : std_logic_vector := x"F2";
    -- SPI Commands
    constant write_reg  : std_logic_vector := x"0A";
    constant read_reg   : std_logic_vector := x"0B";
    constant read_fifo  : std_logic_vector := x"0D";
    -- REGISTER ADDRESSES
    constant adxl362_id_reg : std_logic_vector := x"01";
    constant x_axis_reg     : std_logic_vector := x"08";
    constant y_axis_reg     : std_logic_vector := x"09";
    constant z_axis_reg     : std_logic_vector := x"0A";
    constant status_reg     : std_logic_vector := x"0B";
    constant temp_l         : std_logic_vector := x"14"; -- TEMP L [7:0]
    constant temp_h         : std_logic_vector := x"15"; -- TEMP H [3:0]
    constant fifo_ctrl      : std_logic_vector := x"28";
	type spi_states is (IDLE_S, BIT_WR_S, BIT_RD_S, WR_REG_S, RD_REG_S);
	signal current_state      	: spi_states;

    signal bit_done : std_logic;
    signal rd_reg   : std_logic;
    signal wr_reg   : std_logic;

begin


    -- SPI FSM
    process (clk, rst_n)
    begin
        if(rst_n = '0') then 
            current_state <= IDLE_S;
        elsif rising_edge(clk) then
            case current_state is
                when IDLE_S =>
                    if bit_done = '0' then
                        current_state <= BIT_WR_S;
                    elsif(rd_reg = '1' and wr_reg = '0') then
                        current_state <= RD_REG_S;
                    elsif(wr_reg = '1' and rd_reg = '0') then
                        current_state <= WR_REG_S;
                    end if;
                when BIT_WR_S =>
                    
                when BIT_S => 
                
                when others =>
            
            end case ;
        end if;
    end process;

    -- Output logic
    

end architecture;