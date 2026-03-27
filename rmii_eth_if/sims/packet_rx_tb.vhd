library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ip_defs_pkg.all;

entity packet_rx_tb is
end entity packet_rx_tb;

architecture sim of packet_rx_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk            : std_logic := '0';
    signal reset_n        : std_logic := '0';
    signal RXD            : std_logic_vector(1 downto 0) := "00";
    signal RXDV           : std_logic := '0';
    signal M_AXI_S_TVALID : std_logic;
    signal M_AXI_S_TDATA  : std_logic_vector(7 downto 0);
    signal M_AXI_S_TLAST  : std_logic;

    signal test_name : string(1 to 40) := (others => ' ');

    -- collect process writes these; stim reads them 2 clocks after
    -- lowering 'collecting' (enough time for signal assignment to settle)
    signal collecting    : std_logic := '0';
    signal rx_byte_count : integer   := 0;
    signal saw_tlast     : boolean   := false;

    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

    function build_frame (
        dst_mac  : std_logic_vector(47 downto 0);
        src_mac  : std_logic_vector(47 downto 0);
        src_ip   : std_logic_vector(31 downto 0);
        dst_ip   : std_logic_vector(31 downto 0);
        src_port : std_logic_vector(15 downto 0);
        dst_port : std_logic_vector(15 downto 0);
        payload  : byte_array
    ) return byte_array is
        variable udp_len : std_logic_vector(15 downto 0);
        variable ip_len  : std_logic_vector(15 downto 0);
        variable total   : integer := 42 + payload'length;
        variable frame   : byte_array(0 to total - 1);
    begin
        udp_len := std_logic_vector(to_unsigned(8 + payload'length, 16));
        ip_len  := std_logic_vector(to_unsigned(20 + 8 + payload'length, 16));
        frame(0) := dst_mac(47 downto 40); frame(1) := dst_mac(39 downto 32);
        frame(2) := dst_mac(31 downto 24); frame(3) := dst_mac(23 downto 16);
        frame(4) := dst_mac(15 downto  8); frame(5) := dst_mac( 7 downto  0);
        frame(6)  := src_mac(47 downto 40); frame(7)  := src_mac(39 downto 32);
        frame(8)  := src_mac(31 downto 24); frame(9)  := src_mac(23 downto 16);
        frame(10) := src_mac(15 downto  8); frame(11) := src_mac( 7 downto  0);
        frame(12) := x"08"; frame(13) := x"00";
        frame(14) := x"45"; frame(15) := x"00";
        frame(16) := ip_len(15 downto 8); frame(17) := ip_len(7 downto 0);
        frame(18) := x"00"; frame(19) := x"01";
        frame(20) := x"00"; frame(21) := x"00";
        frame(22) := x"40"; frame(23) := x"11";
        frame(24) := x"00"; frame(25) := x"00";
        frame(26) := src_ip(31 downto 24); frame(27) := src_ip(23 downto 16);
        frame(28) := src_ip(15 downto  8); frame(29) := src_ip( 7 downto  0);
        frame(30) := dst_ip(31 downto 24); frame(31) := dst_ip(23 downto 16);
        frame(32) := dst_ip(15 downto  8); frame(33) := dst_ip( 7 downto  0);
        frame(34) := src_port(15 downto 8); frame(35) := src_port(7 downto 0);
        frame(36) := dst_port(15 downto 8); frame(37) := dst_port(7 downto 0);
        frame(38) := udp_len(15 downto 8);  frame(39) := udp_len(7 downto 0);
        frame(40) := x"00"; frame(41) := x"00";
        for i in payload'range loop
            frame(42 + i - payload'low) := payload(i);
        end loop;
        return frame;
    end function;

    procedure drive_byte (
        signal clk  : in  std_logic;
        signal rxd  : out std_logic_vector(1 downto 0);
        signal rxdv : out std_logic;
        constant b  : in  std_logic_vector(7 downto 0)
    ) is
    begin
        rxdv <= '1';
        rxd <= b(1 downto 0); wait until rising_edge(clk);
        rxd <= b(3 downto 2); wait until rising_edge(clk);
        rxd <= b(5 downto 4); wait until rising_edge(clk);
        rxd <= b(7 downto 6); wait until rising_edge(clk);
    end procedure;

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

    procedure drive_frame (
        signal   clk   : in  std_logic;
        signal   rxd   : out std_logic_vector(1 downto 0);
        signal   rxdv  : out std_logic;
        constant frame : in  byte_array
    ) is
    begin
        rxdv <= '1';
        wait until rising_edge(clk);
        drive_preamble(clk, rxd, rxdv);
        for i in frame'range loop
            drive_byte(clk, rxd, rxdv, frame(i));
        end loop;
        rxdv <= '0';
        rxd  <= "00";
        wait until rising_edge(clk);
    end procedure;

begin

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

    -- ============================================================
    -- Stimulus: raise collecting, drive frame(s), drain pipeline,
    -- lower collecting, wait 4 clocks for collect to write results.
    -- ============================================================
    stim : process
        constant PAYLOAD     : byte_array(0 to 3)    := (x"DE", x"AD", x"BE", x"EF");
        -- Max UDP payload = 1500 (IP MTU) - 20 (IP hdr) - 8 (UDP hdr) = 1472 bytes
        constant MAX_PAYLOAD : byte_array(0 to 1499) := (others => x"A5");

        constant GOOD_FRAME : byte_array := build_frame(
            dst_mac  => FPGA_MAC,        src_mac  => HOST_MAC,
            src_ip   => HOST_IP,         dst_ip   => FPGA_IP,
            src_port => HOST_PORT,       dst_port => FPGA_PORT,
            payload  => PAYLOAD
        );
        constant BAD_FRAME : byte_array := build_frame(
            dst_mac  => x"FFFFFFFFFFFF", src_mac  => HOST_MAC,
            src_ip   => HOST_IP,         dst_ip   => FPGA_IP,
            src_port => HOST_PORT,       dst_port => FPGA_PORT,
            payload  => PAYLOAD
        );
        constant MAX_FRAME : byte_array := build_frame(
            dst_mac  => FPGA_MAC,        src_mac  => HOST_MAC,
            src_ip   => HOST_IP,         dst_ip   => FPGA_IP,
            src_port => HOST_PORT,       dst_port => FPGA_PORT,
            payload  => MAX_PAYLOAD
        );

        -- Clocks after RXDV falls to flush DUT pipeline (3 RXDV + 2 data stages)
        constant DRAIN_CLOCKS : integer := 20;

        variable total_pass : integer := 0;
        variable total_fail : integer := 0;

        -- Record a boolean condition as pass or fail
        procedure check (
            condition : boolean;
            msg       : string
        ) is
        begin
            if condition then
                total_pass := total_pass + 1;
            else
                total_fail := total_fail + 1;
                report "FAIL: " & msg severity error;
            end if;
        end procedure;

    begin
        test_name <= "RESET                                   ";
        reset_n <= '0';
        wait for 5 * CLK_PERIOD;
        reset_n <= '1';
        wait for 3 * CLK_PERIOD;

        -- ---- TEST 1 ----
        test_name <= "TEST1: valid frame, correct MAC         ";
        report "Starting TEST 1: valid frame to FPGA MAC";
        collecting <= '1';
        wait until rising_edge(clk);
        drive_frame(clk, RXD, RXDV, GOOD_FRAME);
        for i in 1 to DRAIN_CLOCKS loop wait until rising_edge(clk); end loop;
        collecting <= '0';
        -- 4 clocks: collect exits its loop, writes signals, done
        wait for 4 * CLK_PERIOD;

        check(rx_byte_count = PAYLOAD'length,
              "TEST1: expected " & integer'image(PAYLOAD'length) &
              " bytes, got " & integer'image(rx_byte_count));
        check(saw_tlast, "TEST1: TLAST never asserted");
        report "TEST 1 complete: " & integer'image(rx_byte_count) & " bytes received";
        wait for 10 * CLK_PERIOD;

        -- ---- TEST 2 ----
        test_name <= "TEST2: wrong MAC, expect no output      ";
        report "Starting TEST 2: frame to broadcast MAC (should be dropped)";
        collecting <= '1';
        wait until rising_edge(clk);
        drive_frame(clk, RXD, RXDV, BAD_FRAME);
        for i in 1 to DRAIN_CLOCKS loop wait until rising_edge(clk); end loop;
        collecting <= '0';
        wait for 4 * CLK_PERIOD;

        check(rx_byte_count = 0,
              "TEST2: received " & integer'image(rx_byte_count) &
              " bytes but expected 0");
        report "TEST 2 complete: " & integer'image(rx_byte_count) & " bytes (expect 0)";
        wait for 10 * CLK_PERIOD;

        -- ---- TEST 3 ----
        test_name <= "TEST3: back-to-back frames              ";
        report "Starting TEST 3: two consecutive valid frames";
        collecting <= '1';
        wait until rising_edge(clk);
        drive_frame(clk, RXD, RXDV, GOOD_FRAME);
        wait for 4 * CLK_PERIOD;
        drive_frame(clk, RXD, RXDV, GOOD_FRAME);
        for i in 1 to DRAIN_CLOCKS loop wait until rising_edge(clk); end loop;
        collecting <= '0';
        wait for 4 * CLK_PERIOD;

        check(rx_byte_count = 2 * PAYLOAD'length,
              "TEST3: expected " & integer'image(2 * PAYLOAD'length) &
              " bytes, got " & integer'image(rx_byte_count));
        report "TEST 3 complete: " & integer'image(rx_byte_count) & " bytes received";
        wait for 10 * CLK_PERIOD;

        -- ---- TEST 4: Max-size frame test ----
        test_name <= "TEST4: max size frame (1500 B payload)  ";
        report "Starting TEST 4: maximum payload frame (1500 bytes)";
        collecting <= '1';
        wait until rising_edge(clk);
        drive_frame(clk, RXD, RXDV, MAX_FRAME);
        for i in 1 to DRAIN_CLOCKS loop wait until rising_edge(clk); end loop;
        collecting <= '0';
        wait for 4 * CLK_PERIOD;

        check(rx_byte_count = MAX_PAYLOAD'length,
              "TEST4: expected " & integer'image(MAX_PAYLOAD'length) &
              " bytes, got " & integer'image(rx_byte_count));
        report "TEST 4 complete: " & integer'image(rx_byte_count) & " bytes received";
        wait for 10 * CLK_PERIOD;

        report "========================================"  severity note;
        report "  TOTAL PASSES : " & integer'image(total_pass) severity note;
        report "  TOTAL FAILS  : " & integer'image(total_fail) severity note;
        report "========================================"  severity note;
        wait;
    end process stim;

    -- ============================================================
    -- Collector: outer loop re-arms for each test automatically.
    -- Uses variables internally; writes to shared signals only once
    -- per test, after the window closes.
    -- ============================================================
    collect : process
        variable cnt  : integer := 0;
        variable last : boolean := false;
    begin
        loop  -- one iteration per test

            wait until collecting = '1';
            cnt  := 0;
            last := false;

            loop  -- sample every clock while window is open
                wait until rising_edge(clk);
                if M_AXI_S_TVALID = '1' then
                    -- Only print individual bytes for small frames (< 16 bytes)
                    -- to avoid flooding the transcript on large frames
                    if cnt < 16 then
                        report "RX byte " & integer'image(cnt) &
                               " = 0x" & to_hstring(M_AXI_S_TDATA);
                    end if;
                    cnt := cnt + 1;
                    if M_AXI_S_TLAST = '1' then last := true; end if;
                end if;
                exit when collecting = '0';
            end loop;

            -- Write final results for stim to read
            rx_byte_count <= cnt;
            saw_tlast     <= last;

        end loop;
    end process collect;

end architecture sim;