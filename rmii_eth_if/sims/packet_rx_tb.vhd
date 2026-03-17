library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ip_defs_pkg.all;

-- ============================================================
-- Testbench for packet_rx
-- Tests:
--   1) Valid UDP/Ethernet frame -> AXI-Stream payload output
--   2) Frame addressed to wrong MAC -> no output (CHECK_DESTINATION=true)
--   3) Packet done mid-stream -> TLAST asserted
-- ============================================================

entity packet_rx_tb is
end entity packet_rx_tb;

architecture sim of packet_rx_tb is


    -- Clock period for 50 MHz RMII ref clock
    constant CLK_PERIOD : time := 20 ns;

    signal clk            : std_logic := '0';
    signal reset_n        : std_logic := '0';
    signal RXD            : std_logic_vector(1 downto 0) := "00";
    signal RXDV           : std_logic := '0';
    signal M_AXI_S_TVALID : std_logic;
    signal M_AXI_S_TDATA  : std_logic_vector(7 downto 0);
    signal M_AXI_S_TLAST  : std_logic;

    signal test_name : string(1 to 40) := (others => ' ');

    -- Byte array type for building frames
    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

    -- Build a minimal valid Ethernet+IPv4+UDP frame header (42 bytes)
    -- followed by a payload.
    -- Layout:
    --   [0..5]   DST MAC
    --   [6..11]  SRC MAC
    --   [12..13] EtherType (0x0800 = IPv4)
    --   [14..33] IPv4 header (20 bytes, minimal, no options)
    --   [34..41] UDP header (8 bytes)
    --   [42+]    payload
    function build_frame (
        dst_mac  : std_logic_vector(47 downto 0);
        src_mac  : std_logic_vector(47 downto 0);
        src_ip   : std_logic_vector(31 downto 0);
        dst_ip   : std_logic_vector(31 downto 0);
        src_port : std_logic_vector(15 downto 0);
        dst_port : std_logic_vector(15 downto 0);
        payload  : byte_array
    ) return byte_array is
        variable udp_len  : std_logic_vector(15 downto 0);
        variable ip_len   : std_logic_vector(15 downto 0);
        variable total    : integer := 42 + payload'length;
        variable frame    : byte_array(0 to total - 1);
    begin
        udp_len := std_logic_vector(to_unsigned(8 + payload'length, 16));
        ip_len  := std_logic_vector(to_unsigned(20 + 8 + payload'length, 16));

        -- DST MAC
        frame(0) := dst_mac(47 downto 40);
        frame(1) := dst_mac(39 downto 32);
        frame(2) := dst_mac(31 downto 24);
        frame(3) := dst_mac(23 downto 16);
        frame(4) := dst_mac(15 downto  8);
        frame(5) := dst_mac( 7 downto  0);
        -- SRC MAC
        frame(6)  := src_mac(47 downto 40);
        frame(7)  := src_mac(39 downto 32);
        frame(8)  := src_mac(31 downto 24);
        frame(9)  := src_mac(23 downto 16);
        frame(10) := src_mac(15 downto  8);
        frame(11) := src_mac( 7 downto  0);
        -- EtherType IPv4
        frame(12) := x"08";
        frame(13) := x"00";
        -- IPv4: ver=4 ihl=5 dscp=0 ecn=0
        frame(14) := x"45";
        frame(15) := x"00";
        -- IPv4 total length
        frame(16) := ip_len(15 downto 8);
        frame(17) := ip_len( 7 downto 0);
        -- identification
        frame(18) := x"00";
        frame(19) := x"01";
        -- flags + fragment offset
        frame(20) := x"00";
        frame(21) := x"00";
        -- TTL
        frame(22) := x"40";
        -- protocol UDP = 17
        frame(23) := x"11";
        -- header checksum (zeroed for sim)
        frame(24) := x"00";
        frame(25) := x"00";
        -- SRC IP
        frame(26) := src_ip(31 downto 24);
        frame(27) := src_ip(23 downto 16);
        frame(28) := src_ip(15 downto  8);
        frame(29) := src_ip( 7 downto  0);
        -- DST IP
        frame(30) := dst_ip(31 downto 24);
        frame(31) := dst_ip(23 downto 16);
        frame(32) := dst_ip(15 downto  8);
        frame(33) := dst_ip( 7 downto  0);
        -- UDP SRC port
        frame(34) := src_port(15 downto 8);
        frame(35) := src_port( 7 downto 0);
        -- UDP DST port
        frame(36) := dst_port(15 downto 8);
        frame(37) := dst_port( 7 downto 0);
        -- UDP length
        frame(38) := udp_len(15 downto 8);
        frame(39) := udp_len( 7 downto 0);
        -- UDP checksum (zeroed for sim)
        frame(40) := x"00";
        frame(41) := x"00";
        -- Payload
        for i in payload'range loop
            frame(42 + i - payload'low) := payload(i);
        end loop;

        return frame;
    end function;

    -- --------------------------------------------------------
    -- Task: drive one byte onto RMII (4 dibits, LSB first)
    -- --------------------------------------------------------
    procedure drive_byte (
        signal clk  : in  std_logic;
        signal rxd  : out std_logic_vector(1 downto 0);
        signal rxdv : out std_logic;
        constant b  : in  std_logic_vector(7 downto 0)
    ) is
    begin
        rxdv <= '1';
        rxd  <= b(1 downto 0); wait until rising_edge(clk);
        rxd  <= b(3 downto 2); wait until rising_edge(clk);
        rxd  <= b(5 downto 4); wait until rising_edge(clk);
        rxd  <= b(7 downto 6); wait until rising_edge(clk);
    end procedure;

    -- --------------------------------------------------------
    -- Task: drive preamble (7 x 0x55) + SFD (0xD5)
    -- --------------------------------------------------------
    procedure drive_preamble (
        signal clk  : in  std_logic;
        signal rxd  : out std_logic_vector(1 downto 0);
        signal rxdv : out std_logic
    ) is
    begin
        for i in 0 to 6 loop
            drive_byte(clk, rxd, rxdv, x"55");
        end loop;
        drive_byte(clk, rxd, rxdv, x"D5");
    end procedure;

    -- --------------------------------------------------------
    -- Task: drive a full frame with preamble
    -- --------------------------------------------------------
    procedure drive_frame (
        signal   clk   : in    std_logic;
        signal   rxd   : out   std_logic_vector(1 downto 0);
        signal   rxdv  : out   std_logic;
        constant frame : in    byte_array
    ) is
    begin
        -- Assert RXDV one cycle before preamble
        rxdv <= '1';
        wait until rising_edge(clk);
        drive_preamble(clk, rxd, rxdv);
        for i in frame'range loop
            drive_byte(clk, rxd, rxdv, frame(i));
        end loop;
        -- De-assert RXDV = end of packet
        rxdv <= '0';
        rxd  <= "00";
        wait until rising_edge(clk);
    end procedure;

begin

    -- --------------------------------------------------------
    -- DUT instantiation
    -- --------------------------------------------------------
    DUT : entity work.packet_rx
        port map (
            clk            => clk,
            reset_n        => reset_n,
            RXD            => RXD,
            RXDV           => RXDV,
            M_AXI_S_TVALID => M_AXI_S_TVALID,
            M_AXI_S_TDATA  => M_AXI_S_TDATA,
            M_AXI_S_TLAST  => M_AXI_S_TLAST
        );

    clk <= not clk after CLK_PERIOD / 2;

    stim : process
        -- Payload: 4 known bytes
        constant PAYLOAD : byte_array(0 to 3) := (x"DE", x"AD", x"BE", x"EF");

        -- Frame addressed to FPGA (should pass)
        constant GOOD_FRAME : byte_array := build_frame(
            dst_mac  => FPGA_MAC,
            src_mac  => HOST_MAC,
            src_ip   => HOST_IP,
            dst_ip   => FPGA_IP,
            src_port => HOST_PORT,
            dst_port => FPGA_PORT,
            payload  => PAYLOAD
        );

        -- Frame addressed to wrong MAC (should be dropped)
        constant BAD_FRAME : byte_array := build_frame(
            dst_mac  => x"FFFFFFFFFFFF",  -- broadcast, not FPGA_MAC
            src_mac  => HOST_MAC,
            src_ip   => HOST_IP,
            dst_ip   => FPGA_IP,
            src_port => HOST_PORT,
            dst_port => FPGA_PORT,
            payload  => PAYLOAD
        );

        variable rx_byte_count : integer := 0;
        variable saw_tlast     : boolean := false;
    begin
        -- ---- Reset ----
        test_name <= "RESET                                   ";
        reset_n <= '0';
        wait for 5 * CLK_PERIOD;
        reset_n <= '1';
        wait for 3 * CLK_PERIOD;

        -- ================================================
        -- TEST 1: Valid frame, correct destination
        -- Expected: 4 payload bytes on AXI-S, TLAST on last
        -- ================================================
        test_name <= "TEST1: valid frame, correct MAC         ";
        report "Starting TEST 1: valid frame to FPGA MAC";

        drive_frame(clk, RXD, RXDV, GOOD_FRAME);

        -- Wait and collect output
        rx_byte_count := 0;
        saw_tlast     := false;
        for i in 0 to 50 loop
            wait until rising_edge(clk);
            if M_AXI_S_TVALID = '1' then
                report "RX byte " & integer'image(rx_byte_count) &
                       " = 0x" & to_hstring(M_AXI_S_TDATA);
                -- Check payload values
                case rx_byte_count is
                    when 0 => assert M_AXI_S_TDATA = x"DE"
                        report "FAIL: byte 0 expected 0xDE" severity error;
                    when 1 => assert M_AXI_S_TDATA = x"AD"
                        report "FAIL: byte 1 expected 0xAD" severity error;
                    when 2 => assert M_AXI_S_TDATA = x"BE"
                        report "FAIL: byte 2 expected 0xBE" severity error;
                    when 3 => assert M_AXI_S_TDATA = x"EF"
                        report "FAIL: byte 3 expected 0xEF" severity error;
                    when others => null;
                end case;
                rx_byte_count := rx_byte_count + 1;
                if M_AXI_S_TLAST = '1' then
                    saw_tlast := true;
                end if;
            end if;
        end loop;

        assert rx_byte_count = PAYLOAD'length
            report "FAIL TEST1: expected " & integer'image(PAYLOAD'length) &
                   " bytes, got " & integer'image(rx_byte_count)
            severity error;
        assert saw_tlast
            report "FAIL TEST1: TLAST never asserted"
            severity error;

        report "TEST 1 complete: " & integer'image(rx_byte_count) & " bytes received";
        wait for 10 * CLK_PERIOD;

        -- ================================================
        -- TEST 2: Frame to wrong MAC, CHECK_DESTINATION=true
        -- Expected: no AXI-S output
        -- ================================================
        test_name <= "TEST2: wrong MAC, expect no output      ";
        report "Starting TEST 2: frame to broadcast MAC (should be dropped)";

        drive_frame(clk, RXD, RXDV, BAD_FRAME);

        rx_byte_count := 0;
        for i in 0 to 50 loop
            wait until rising_edge(clk);
            if M_AXI_S_TVALID = '1' then
                rx_byte_count := rx_byte_count + 1;
            end if;
        end loop;

        assert rx_byte_count = 0
            report "FAIL TEST2: received " & integer'image(rx_byte_count) &
                   " bytes but expected 0 (wrong MAC should be dropped)"
            severity error;

        report "TEST 2 complete: " & integer'image(rx_byte_count) & " bytes (expect 0)";
        wait for 10 * CLK_PERIOD;

        -- ================================================
        -- TEST 3: Back-to-back frames
        -- ================================================
        test_name <= "TEST3: back-to-back frames              ";
        report "Starting TEST 3: two consecutive valid frames";

        drive_frame(clk, RXD, RXDV, GOOD_FRAME);
        wait for 4 * CLK_PERIOD;
        drive_frame(clk, RXD, RXDV, GOOD_FRAME);

        rx_byte_count := 0;
        for i in 0 to 120 loop
            wait until rising_edge(clk);
            if M_AXI_S_TVALID = '1' then
                rx_byte_count := rx_byte_count + 1;
            end if;
        end loop;

        assert rx_byte_count = 2 * PAYLOAD'length
            report "FAIL TEST3: expected " & integer'image(2 * PAYLOAD'length) &
                   " bytes, got " & integer'image(rx_byte_count)
            severity error;

        report "TEST 3 complete: " & integer'image(rx_byte_count) & " bytes received";
        wait for 10 * CLK_PERIOD;

        -- ================================================
        -- Done
        -- ================================================
        report "All tests complete" severity note;
        wait;
    end process stim;
 
end architecture sim;