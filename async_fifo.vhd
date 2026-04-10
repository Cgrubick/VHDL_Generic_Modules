-- Asynchronous FIFO
-- Uses Gray-code pointer synchronization to safely cross clock domains.
-- DATA_WIDTH : width of the data bus
-- ADDR_WIDTH : log2 of the FIFO depth (depth = 2**ADDR_WIDTH)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity async_fifo is
    generic (
        DATA_WIDTH : positive := 8;
        ADDR_WIDTH : positive := 4   -- depth = 2**ADDR_WIDTH
    );
    port (
        -- Write side
        wr_clk   : in  std_logic;
        wr_rst_n : in  std_logic;
        wr_en    : in  std_logic;
        wr_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        wr_full  : out std_logic;

        -- Read side
        rd_clk   : in  std_logic;
        rd_rst_n : in  std_logic;
        rd_en    : in  std_logic;
        rd_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        rd_empty : out std_logic
    );
end entity async_fifo;

architecture rtl of async_fifo is

    constant DEPTH : positive := 2**ADDR_WIDTH;

    -- Dual-port RAM
    type ram_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_t;

    -- Write-domain pointers (binary and Gray)
    signal wr_ptr_bin  : unsigned(ADDR_WIDTH downto 0) := (others => '0');
    signal wr_ptr_gray : std_logic_vector(ADDR_WIDTH downto 0) := (others => '0');

    -- Read-domain pointers (binary and Gray)
    signal rd_ptr_bin  : unsigned(ADDR_WIDTH downto 0) := (others => '0');
    signal rd_ptr_gray : std_logic_vector(ADDR_WIDTH downto 0) := (others => '0');

    -- Synchronized Gray pointers
    signal rd_ptr_gray_wr1, rd_ptr_gray_wr2 : std_logic_vector(ADDR_WIDTH downto 0) := (others => '0');
    signal wr_ptr_gray_rd1, wr_ptr_gray_rd2 : std_logic_vector(ADDR_WIDTH downto 0) := (others => '0');

    -- Internal flags
    signal full_i          : std_logic;
    signal empty_i         : std_logic;
    signal wr_ptr_gray_next : std_logic_vector(ADDR_WIDTH downto 0);

    -- Convert binary to Gray code
    function bin_to_gray(b : unsigned) return std_logic_vector is
    begin
        return std_logic_vector(b xor ('0' & b(b'high downto 1)));
    end function;

begin

    wr_full  <= full_i;
    rd_empty <= empty_i;

    -- Write port
    p_write : process(wr_clk)
    begin
        if rising_edge(wr_clk) then
            if wr_en = '1' and full_i = '0' then
                ram(to_integer(wr_ptr_bin(ADDR_WIDTH-1 downto 0))) <= wr_data;
            end if;
        end if;
    end process;

    -- Write pointer update
    p_wr_ptr : process(wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then
            wr_ptr_bin  <= (others => '0');
            wr_ptr_gray <= (others => '0');
        elsif rising_edge(wr_clk) then
            if wr_en = '1' and full_i = '0' then
                wr_ptr_bin  <= wr_ptr_bin + 1;
                wr_ptr_gray <= bin_to_gray(wr_ptr_bin + 1);
            end if;
        end if;
    end process;

    -- Synchronize read Gray pointer into write clock domain (2-FF synchronizer)
    p_sync_rd_ptr : process(wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then
            rd_ptr_gray_wr1 <= (others => '0');
            rd_ptr_gray_wr2 <= (others => '0');
        elsif rising_edge(wr_clk) then
            rd_ptr_gray_wr1 <= rd_ptr_gray;
            rd_ptr_gray_wr2 <= rd_ptr_gray_wr1;
        end if;
    end process;

    -- Next write pointer in Gray code (combinatorial)
    wr_ptr_gray_next <= bin_to_gray(wr_ptr_bin + 1);

    -- Full: next write Gray ptr matches read Gray ptr with top 2 bits inverted
    p_full : process(wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then
            full_i <= '0';
        elsif rising_edge(wr_clk) then
            if wr_ptr_gray_next = (not rd_ptr_gray_wr2(ADDR_WIDTH downto ADDR_WIDTH-1) & rd_ptr_gray_wr2(ADDR_WIDTH-2 downto 0)) then
                full_i <= '1';
            else
                full_i <= '0';
            end if;
        end if;
    end process;

    -- Read port
    rd_data <= ram(to_integer(rd_ptr_bin(ADDR_WIDTH-1 downto 0)));

    -- Read pointer update
    p_rd_ptr : process(rd_clk, rd_rst_n)
    begin
        if rd_rst_n = '0' then
            rd_ptr_bin  <= (others => '0');
            rd_ptr_gray <= (others => '0');
        elsif rising_edge(rd_clk) then
            if rd_en = '1' and empty_i = '0' then
                rd_ptr_bin  <= rd_ptr_bin + 1;
                rd_ptr_gray <= bin_to_gray(rd_ptr_bin + 1);
            end if;
        end if;
    end process;

    -- Synchronize write Gray pointer into read clock domain (2-FF synchronizer)
    p_sync_wr_ptr : process(rd_clk, rd_rst_n)
    begin
        if rd_rst_n = '0' then
            wr_ptr_gray_rd1 <= (others => '0');
            wr_ptr_gray_rd2 <= (others => '0');
        elsif rising_edge(rd_clk) then
            wr_ptr_gray_rd1 <= wr_ptr_gray;
            wr_ptr_gray_rd2 <= wr_ptr_gray_rd1;
        end if;
    end process;

    -- Empty: read Gray ptr equals synchronized write Gray ptr
    p_empty : process(rd_clk, rd_rst_n)
    begin
        if rd_rst_n = '0' then
            empty_i <= '1';
        elsif rising_edge(rd_clk) then
            if rd_ptr_gray = wr_ptr_gray_rd2 then
                empty_i <= '1';
            else
                empty_i <= '0';
            end if;
        end if;
    end process;

end architecture rtl;
