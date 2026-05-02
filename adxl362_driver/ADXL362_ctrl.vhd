-- ##Accelerometer - Constraints
--  ACL_MISO
--  ACL_MOSI
--  ACL_SCLK
--  ACL_CSN 
--  ACL_INT[1] 
--  ACL_INT[2] 




entity ADXL362_ctrl is
    port (
        clk         : in std_logic;
        rst_n       : in std_logic;
        ACL_INT     : in std_logic_vector(1 downto 0);
        ACL_MOSI    : in std_logic;
        ACL_MISO    : out std_logic;
        ACL_SCLK    : out std_logic;
        ACL_CSN     : out std_logic
    );
end entity ADXL362_ctrl;

architecture rtl of ADXL362_ctrl is

begin

    

end architecture;