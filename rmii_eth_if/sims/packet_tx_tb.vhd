library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ip_defs_pkg.all;

entity packet_tx_tb is
end entity packet_tx_tb;

architecture sim of packet_tx_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk            : std_logic := '0';
    signal reset_n        : std_logic := '0';
    signal S_AXI_S_TVALID : std_logic := '0';
    signal S_AXI_S_TDATA  : std_logic_vector(7 downto 0) := (others => '0');
    signal S_AXI_S_TLAST  : std_logic := '0';
    signal S_AXI_S_TREADY : std_logic;
    signal ETH_TXD        : std_logic_vector(1 downto 0);
    signal ETH_TXEN       : std_logic;

    signal test_name : string(1 to 40) := (others => ' ');

    -- collect process writes these; stim reads them 4 clocks after
    -- lowering 'collecting' (enough time for signal assignment to settle)
    signal collecting    : std_logic := '0';
    signal tx_byte_count : integer   := 0;
    signal saw_preamble  : boolean   := false;
    signal saw_sfd       : boolean   := false;

    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

    -- Send one byte over AXI-S; waits for TREADY handshake
    procedure send_byte (
        signal clk    : in  std_logic;
        signal tvalid : out std_logic;
        signal tdata  : out std_logic_vector(7 downto 0);
        signal tlast  : out std_logic;
        signal tready : in  std_logic;
        constant b    : in  std_logic_vector(7 downto 0);
        constant last : in  boolean := false
    ) is
    begin
        tdata  <= b;
        tvalid <= '1';
        if last then tlast <= '1'; else tlast <= '0'; end if;
        loop
            wait until rising_edge(clk);
            exit when tready = '1';
        end loop;
        tvalid <= '0';
        tlast  <= '0';
    end procedure;

    -- Send a payload byte array as an AXI-S stream; TLAST asserted on final byte
    procedure send_packet (
        signal clk     : in  std_logic;
        signal tvalid  : out std_logic;
        signal tdata   : out std_logic_vector(7 downto 0);
        signal tlast   : out std_logic;
        signal tready  : in  std_logic;
        constant bytes : in  byte_array
    ) is
    begin
        for i in bytes'range loop
            send_byte(clk, tvalid, tdata, tlast, tready,
                      bytes(i), last => (i = bytes'high));
        end loop;
    end procedure;

begin

    DUT : entity work.packet_tx
        port map (
            clk            => clk,
            reset_n        => reset_n,
            data_i         => (others => '0'),
            S_AXI_S_TVALID => S_AXI_S_TVALID,
            S_AXI_S_TDATA  => S_AXI_S_TDATA,
            S_AXI_S_TLAST  => S_AXI_S_TLAST,
            S_AXI_S_TREADY => S_AXI_S_TREADY,
            ETH_TXD        => ETH_TXD,
            ETH_TXEN       => ETH_TXEN
        );

    clk <= not clk after CLK_PERIOD / 2;

    -- ============================================================
    -- Stimulus: raise collecting, drive AXI-S payload, drain pipeline,
    -- lower collecting, wait 4 clocks for collect to write results.
    -- ============================================================
    stim : process
        constant PAYLOAD      : byte_array(0 to 3)   := (x"DE", x"AD", x"BE", x"EF");
        constant LONG_PAYLOAD : byte_array(0 to 63)  := (others => x"A5");

        -- Clocks after last AXI-S handshake to flush TX pipeline:
        -- preamble(32) + header(168) + payload(n*4) + FCS(16) + margin
        constant DRAIN_CLOCKS : integer := 500;

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
        test_name <= "TEST1: small payload (4 bytes)          ";
        report "Starting TEST 1: 4-byte payload";
        collecting <= '1';
        wait until rising_edge(clk);
        send_packet(clk, S_AXI_S_TVALID, S_AXI_S_TDATA, S_AXI_S_TLAST,
                    S_AXI_S_TREADY, PAYLOAD);
        for i in 1 to DRAIN_CLOCKS loop wait until rising_edge(clk); end loop;
        collecting <= '0';
        wait for 4 * CLK_PERIOD;

        -- After SFD: 42 header + 4 payload + 4 FCS = 50 bytes
        check(saw_preamble, "TEST1: preamble (7x 0x55) not detected");
        check(saw_sfd,      "TEST1: SFD (0xD5) not detected");
        check(tx_byte_count = 42 + PAYLOAD'length + 4,
              "TEST1: expected " & integer'image(42 + PAYLOAD'length + 4) &
              " bytes after SFD, got " & integer'image(tx_byte_count));
        report "TEST 1 complete: " & integer'image(tx_byte_count) & " bytes after SFD";
        wait for 10 * CLK_PERIOD;

        -- ---- TEST 2: back-to-back ----
        test_name <= "TEST2: back-to-back packets             ";
        report "Starting TEST 2: two consecutive packets";
        collecting <= '1';
        wait until rising_edge(clk);
        send_packet(clk, S_AXI_S_TVALID, S_AXI_S_TDATA, S_AXI_S_TLAST,
                    S_AXI_S_TREADY, PAYLOAD);
        wait for 4 * CLK_PERIOD;
        send_packet(clk, S_AXI_S_TVALID, S_AXI_S_TDATA, S_AXI_S_TLAST,
                    S_AXI_S_TREADY, PAYLOAD);
        for i in 1 to DRAIN_CLOCKS loop wait until rising_edge(clk); end loop;
        collecting <= '0';
        wait for 4 * CLK_PERIOD;

        -- Two frames: 2 × (42 + 4 payload + 4 FCS) = 100 bytes after SFDs
        check(tx_byte_count = 2 * (42 + PAYLOAD'length + 4),
              "TEST2: expected " & integer'image(2 * (42 + PAYLOAD'length + 4)) &
              " bytes, got " & integer'image(tx_byte_count));
        report "TEST 2 complete: " & integer'image(tx_byte_count) & " bytes after SFDs";
        wait for 10 * CLK_PERIOD;

        -- ---- TEST 3: 64-byte payload ----
        test_name <= "TEST3: 64-byte payload                  ";
        report "Starting TEST 3: 64-byte payload";
        collecting <= '1';
        wait until rising_edge(clk);
        send_packet(clk, S_AXI_S_TVALID, S_AXI_S_TDATA, S_AXI_S_TLAST,
                    S_AXI_S_TREADY, LONG_PAYLOAD);
        for i in 1 to DRAIN_CLOCKS loop wait until rising_edge(clk); end loop;
        collecting <= '0';
        wait for 4 * CLK_PERIOD;

        -- After SFD: 42 header + 64 payload + 4 FCS = 110 bytes
        check(tx_byte_count = 42 + LONG_PAYLOAD'length + 4,
              "TEST3: expected " & integer'image(42 + LONG_PAYLOAD'length + 4) &
              " bytes after SFD, got " & integer'image(tx_byte_count));
        report "TEST 3 complete: " & integer'image(tx_byte_count) & " bytes after SFD";
        wait for 10 * CLK_PERIOD;

        report "========================================"  severity note;
        report "  TOTAL PASSES : " & integer'image(total_pass) severity note;
        report "  TOTAL FAILS  : " & integer'image(total_fail) severity note;
        report "========================================"  severity note;
        wait;
    end process stim;

    -- ============================================================
    -- Collector: samples ETH_TXD dibits while ETH_TXEN=1,
    -- reassembles bytes LSB-first, detects preamble/SFD per frame,
    -- counts post-SFD bytes (header + payload + FCS) across all frames
    -- in the test window.
    -- ============================================================
    collect : process
        type col_state_t is (PREAMBLE_C, DATA_C);
        variable col_state    : col_state_t := PREAMBLE_C;
        variable cnt          : integer := 0;
        variable dibit_idx    : integer := 0;
        variable cur_byte     : std_logic_vector(7 downto 0) := (others => '0');
        variable preamble_cnt : integer := 0;
        variable preamble_ok  : boolean := false;
        variable sfd_ok       : boolean := false;
    begin
        loop  -- one iteration per test

            wait until collecting = '1';
            cnt          := 0;
            dibit_idx    := 0;
            cur_byte     := (others => '0');
            preamble_cnt := 0;
            preamble_ok  := false;
            sfd_ok       := false;
            col_state    := PREAMBLE_C;

            loop  -- sample every clock while window is open
                wait until rising_edge(clk);
                if ETH_TXEN = '1' then
                    -- Accumulate dibits LSB-first into cur_byte
                    case dibit_idx is
                        when 0 => cur_byte(1 downto 0) := ETH_TXD;
                        when 1 => cur_byte(3 downto 2) := ETH_TXD;
                        when 2 => cur_byte(5 downto 4) := ETH_TXD;
                        when 3 => cur_byte(7 downto 6) := ETH_TXD;
                        when others => null;
                    end case;
                    dibit_idx := (dibit_idx + 1) mod 4;

                    if dibit_idx = 0 then  -- completed a full byte
                        case col_state is
                            when PREAMBLE_C =>
                                if cur_byte = x"55" then
                                    preamble_cnt := preamble_cnt + 1;
                                elsif cur_byte = x"D5" then
                                    sfd_ok      := true;
                                    preamble_ok := (preamble_cnt >= 7);
                                    col_state   := DATA_C;
                                    preamble_cnt := 0;
                                end if;
                            when DATA_C =>
                                -- Only print individual bytes for small frames
                                -- to avoid flooding the transcript on large frames
                                if cnt < 16 then
                                    report "TX byte " & integer'image(cnt) &
                                           " = 0x" & to_hstring(cur_byte);
                                end if;
                                cnt := cnt + 1;
                        end case;
                    end if;
                else
                    -- ETH_TXEN deasserted: reset accumulator for next frame
                    dibit_idx := 0;
                    cur_byte  := (others => '0');
                    col_state := PREAMBLE_C;
                end if;
                exit when collecting = '0';
            end loop;

            -- Write final results for stim to read
            tx_byte_count <= cnt;
            saw_preamble  <= preamble_ok;
            saw_sfd       <= sfd_ok;

        end loop;
    end process collect;

end architecture sim;
