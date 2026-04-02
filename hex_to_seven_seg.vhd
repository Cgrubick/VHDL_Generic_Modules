library ieee;
use ieee.std_logic_1164.all;

entity hex_to_seven_seg is
    port (
        hex       : in  std_logic_vector(3 downto 0);
        seven_seg : out std_logic_vector(6 downto 0)
    );
end entity hex_to_seven_seg;

architecture rtl of hex_to_seven_seg is
begin

    process(hex)
    begin
        case hex is  -- gfedcba
            when x"0" => seven_seg <= "1000000";
            when x"1" => seven_seg <= "1111001";
            when x"2" => seven_seg <= "0100100";
            when x"3" => seven_seg <= "0110000";
            when x"4" => seven_seg <= "0011001";
            when x"5" => seven_seg <= "0010010";
            when x"6" => seven_seg <= "0000010";
            when x"7" => seven_seg <= "1111000";
            when x"8" => seven_seg <= "0000000";
            when x"9" => seven_seg <= "0010000";
            when x"A" => seven_seg <= "0001000";
            when x"B" => seven_seg <= "1000011";
            when x"C" => seven_seg <= "1000110";
            when x"D" => seven_seg <= "0100001";
            when x"E" => seven_seg <= "0000110";
            when x"F" => seven_seg <= "0001110";
            when others => seven_seg <= "1111111";
        end case;
    end process;

end architecture rtl;
