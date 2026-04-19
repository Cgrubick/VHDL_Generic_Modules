library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.ip_defs_pkg.all;

entity packet_tx_tb is
end entity packet_tx_tb;

architecture tb of packet_tx_tb is

    signal clk            : std_logic := '0';
    signal reset_n        : std_logic := '0';
    signal S_AXI_S_TVALID : std_logic := '0';
    signal S_AXI_S_TDATA  : std_logic_vector(7 downto 0) := (others => '0');
    signal S_AXI_S_TLAST  : std_logic := '0';
    signal S_AXI_S_TREADY : std_logic;
    signal ETH_TXD        : std_logic_vector(1 downto 0);
    signal ETH_TXEN       : std_logic;

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

    type byte_array_t  is array (natural range <>) of std_logic_vector(7 downto 0);
    type dibit_array_t is array (natural range <>) of std_logic_vector(1 downto 0);

    -- CRC-32: poly = 0xEDB88320, init = 0xFFFFFFFF, no final XOR.
    -- Feeding (header + payload + FCS) through this must yield residue 0x2144DF1C.
    function crc32 (data : byte_array_t) return std_logic_vector is
        variable crc     : unsigned(31 downto 0) := x"FFFFFFFF";
        variable bit_val : std_logic;
    begin
        for i in data'range loop
            for j in 0 to 7 loop
                bit_val := data(i)(j) xor crc(0);
                crc     := shift_right(crc, 1);
                if bit_val = '1' then
                    crc := crc xor x"EDB88320";
                end if;
            end loop;
        end loop;
        return std_logic_vector(crc);
    end function;

begin

    clk <= not clk after CLK_PERIOD / 2;

    DUT : entity work.packet_tx
        port map (
            clk            => clk,
            reset_n        => reset_n,
            S_AXI_S_TVALID => S_AXI_S_TVALID,
            S_AXI_S_TDATA  => S_AXI_S_TDATA,
            S_AXI_S_TLAST  => S_AXI_S_TLAST,
            S_AXI_S_TREADY => S_AXI_S_TREADY,
            ETH_TXD        => ETH_TXD,
            ETH_TXEN       => ETH_TXEN
        );

    -- ----------------------------------------------------------------
    -- Stimulus
    -- ----------------------------------------------------------------
    stimulus : process

        procedure send_byte (
            data : in std_logic_vector(7 downto 0);
            last : in boolean
        ) is
        begin
            S_AXI_S_TDATA  <= data;
            S_AXI_S_TVALID <= '1';
            if last then S_AXI_S_TLAST <= '1'; else S_AXI_S_TLAST <= '0'; end if;
            loop
                wait until rising_edge(clk);
                exit when S_AXI_S_TREADY = '1';
            end loop;
            S_AXI_S_TVALID <= '0';
            S_AXI_S_TLAST  <= '0';
        end procedure;

        procedure send_packet (payload : byte_array_t) is
        begin
            for i in payload'range loop
                send_byte(payload(i), i = payload'right);
            end loop;
        end procedure;

        constant PAYLOAD_1 : byte_array_t(0 to 3) := (x"DE", x"AD", x"BE", x"EF");
        constant PAYLOAD_2 : byte_array_t(0 to 3) := (x"01", x"02", x"03", x"04");

    begin
        reset_n <= '0';
        wait for 5 * CLK_PERIOD;
        wait until rising_edge(clk);
        reset_n <= '1';
        wait for 2 * CLK_PERIOD;

        send_packet(PAYLOAD_1);
        wait until ETH_TXEN = '0';
        wait for 20 * CLK_PERIOD;

        send_packet(PAYLOAD_2);
        wait until ETH_TXEN = '0';
        wait for 20 * CLK_PERIOD;

        send_packet(PAYLOAD_1);
        wait until ETH_TXEN = '0';
        wait for 10 * CLK_PERIOD;

        report "Stimulus complete" severity note;
        wait;
    end process;

    -- ----------------------------------------------------------------
    -- Frame checker: captures each transmitted frame, strips preamble/SFD,
    -- runs CRC-32 over (header + payload + FCS), checks residue = 0x2144DF1C.
    -- ----------------------------------------------------------------
    checker : process
        constant MAX_DIBITS : integer := 1200;
        constant MAX_BYTES  : integer := 300;

        variable dibits    : dibit_array_t(0 to MAX_DIBITS - 1);
        variable dibit_cnt : integer;
        variable raw       : byte_array_t(0 to MAX_BYTES - 1);
        variable raw_len   : integer;
        variable frame     : byte_array_t(0 to MAX_BYTES - 1);
        variable frame_len : integer;
        variable b         : std_logic_vector(7 downto 0);
        variable sfd_found : boolean;
        variable sfd_pos   : integer;
        variable residue   : std_logic_vector(31 downto 0);
        variable pkt_num   : integer := 0;
    begin
        loop
            -- Wait for TXEN then align to a rising edge so delta-cycle updates settle
            wait until ETH_TXEN = '1';
            wait until rising_edge(clk);
            wait for 1 ps;

            -- Collect one dibit per clock while TXEN is high
            dibit_cnt := 0;
            while ETH_TXEN = '1' loop
                dibits(dibit_cnt) := ETH_TXD;
                dibit_cnt := dibit_cnt + 1;
                wait until rising_edge(clk);
                wait for 1 ps;
            end loop;

            -- Reassemble bytes: 4 dibits per byte, transmitted LSB-first
            raw_len := dibit_cnt / 4;
            for i in 0 to raw_len - 1 loop
                b(1 downto 0) := dibits(i*4);
                b(3 downto 2) := dibits(i*4 + 1);
                b(5 downto 4) := dibits(i*4 + 2);
                b(7 downto 6) := dibits(i*4 + 3);
                raw(i) := b;
            end loop;

            -- Locate SFD byte (0xD5); preamble bytes are 0x55
            sfd_found := false;
            sfd_pos   := 0;
            for i in 0 to raw_len - 1 loop
                if raw(i) = x"D5" and not sfd_found then
                    sfd_found := true;
                    sfd_pos   := i + 1;  -- frame bytes start immediately after SFD
                end if;
            end loop;

            pkt_num := pkt_num + 1;

            if not sfd_found then
                report "PKT " & integer'image(pkt_num)
                       & ": ERROR - SFD (0xD5) not found in " & integer'image(raw_len)
                       & " raw bytes" severity note;
            else
                frame_len := raw_len - sfd_pos;
                for i in 0 to frame_len - 1 loop
                    frame(i) := raw(sfd_pos + i);
                end loop;

                if frame_len < 4 then
                    report "PKT " & integer'image(pkt_num)
                           & ": ERROR - frame too short (" & integer'image(frame_len)
                           & " bytes after SFD)" severity note;
                else
                    -- CRC check: residue over (header + payload + FCS) must equal 0x2144DF1C
                    residue := crc32(frame(0 to frame_len - 1));
                    if residue = x"2144DF1C" then
                        report "PKT " & integer'image(pkt_num)
                               & ": FCS PASS  (" & integer'image(frame_len)
                               & " bytes after SFD)" severity note;
                    else
                        report "PKT " & integer'image(pkt_num)
                               & ": FCS FAIL  residue = 0x" & to_hstring(residue)
                               & "  expected 0x2144DF1C" severity note;
                    end if;
                end if;
            end if;
        end loop;
    end process;

end architecture tb;
