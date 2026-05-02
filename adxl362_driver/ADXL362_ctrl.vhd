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
    --REGISTER ADDRESSES
    constant adxl362_id_reg : std_logic_vector := x"01";
    
    constant x_axis_reg     : std_logic_vector := x"08";
    constant y_axis_reg     : std_logic_vector := x"09";
    constant z_axis_reg     : std_logic_vector := x"0A";
	type spi_states is (IDLE_S, BIT_WR_S, BIT_RD_S);
	signal current_state      	: spi_states;

begin


    -- SPI FSM
    process (clk, rst_n)
    begin
        if(rst_n = '0') then 
            current_state <= IDLE_S;
        elsif rising_edge(clk) then
            case current_state is
            
                when IDLE_S =>
                    
                when BIT_S => 
                
                when others =>
            
            end case ;
        end if;
    end process;

    -- Output logic
    

end architecture;