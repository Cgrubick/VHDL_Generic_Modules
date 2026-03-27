-- vim: ts=4 sw=4 expandtab

-- THIS IS GENERATED VHDL CODE.
-- https://bues.ch/h/crcgen
-- CRC polynomial coefficients: x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
--                              0xEDB88320 (hex)
-- CRC width:                   32 bits
-- CRC shift direction:         right (little endian)
-- Input word width:            2 bits

library IEEE;
use IEEE.std_logic_1164.all;

entity crc_32 is
    port (
        crc_in  : in std_logic_vector(31 downto 0);
        crc_en  : in std_logic;
        data    : in std_logic_vector(1 downto 0);
        crc_out : out std_logic_vector(31 downto 0)
    );
end entity crc_32;

architecture Behavioral of crc_32 is
    signal crc_out_reg  : std_logic_vector(31 downto 0);
begin
    crc_out_reg(0) <= crc_in(2);
    crc_out_reg(1) <= crc_in(3);
    crc_out_reg(2) <= crc_in(4);
    crc_out_reg(3) <= crc_in(5);
    crc_out_reg(4) <= crc_in(0) xor crc_in(6) xor data(0);
    crc_out_reg(5) <= crc_in(1) xor crc_in(7) xor data(1);
    crc_out_reg(6) <= crc_in(8);
    crc_out_reg(7) <= crc_in(0) xor crc_in(9) xor data(0);
    crc_out_reg(8) <= crc_in(0) xor crc_in(1) xor crc_in(10) xor data(0) xor data(1);
    crc_out_reg(9) <= crc_in(1) xor crc_in(11) xor data(1);
    crc_out_reg(10) <= crc_in(12);
    crc_out_reg(11) <= crc_in(13);
    crc_out_reg(12) <= crc_in(14);
    crc_out_reg(13) <= crc_in(15);
    crc_out_reg(14) <= crc_in(0) xor crc_in(16) xor data(0);
    crc_out_reg(15) <= crc_in(1) xor crc_in(17) xor data(1);
    crc_out_reg(16) <= crc_in(18);
    crc_out_reg(17) <= crc_in(19);
    crc_out_reg(18) <= crc_in(0) xor crc_in(20) xor data(0);
    crc_out_reg(19) <= crc_in(0) xor crc_in(1) xor crc_in(21) xor data(0) xor data(1);
    crc_out_reg(20) <= crc_in(0) xor crc_in(1) xor crc_in(22) xor data(0) xor data(1);
    crc_out_reg(21) <= crc_in(1) xor crc_in(23) xor data(1);
    crc_out_reg(22) <= crc_in(0) xor crc_in(24) xor data(0);
    crc_out_reg(23) <= crc_in(0) xor crc_in(1) xor crc_in(25) xor data(0) xor data(1);
    crc_out_reg(24) <= crc_in(1) xor crc_in(26) xor data(1);
    crc_out_reg(25) <= crc_in(0) xor crc_in(27) xor data(0);
    crc_out_reg(26) <= crc_in(0) xor crc_in(1) xor crc_in(28) xor data(0) xor data(1);
    crc_out_reg(27) <= crc_in(1) xor crc_in(29) xor data(1);
    crc_out_reg(28) <= crc_in(0) xor crc_in(30) xor data(0);
    crc_out_reg(29) <= crc_in(0) xor crc_in(1) xor crc_in(31) xor data(0) xor data(1);
    crc_out_reg(30) <= crc_in(0) xor crc_in(1) xor data(0) xor data(1);
    crc_out_reg(31) <= crc_in(1) xor data(1);

    crc_out <= crc_out_reg when crc_en = '1' else (others => '0');

end architecture Behavioral;