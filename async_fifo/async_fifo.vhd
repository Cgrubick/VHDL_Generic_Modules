library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; 

entity async_fifo is
    generic (
        WIDTH   : integer := 32;
        DEPTH   : integer := 32;
        AF_LEVEL: integer := 2
    );
    port (
        -- Write Side
        wr_rst_n    : in std_logic;
        wr_data     : in std_logic_vector(WIDTH - 1 downto 0);
        wr_en       : in std_logic;
        wr_clk      : in std_logic;
        -- Read Side
        rd_rst_n    : in std_logic;
        rd_data     : out std_logic_vector(WIDTH - 1 downto 0);
        rd_en       : in std_logic;
        rd_clk      : in std_logic;
        -- Status
        ae          : out std_logic;
        af          : out std_logic;
        full        : out std_logic;
        empty       : out std_logic
    );
end entity async_fifo;

architecture rtl of async_fifo is

    constant ADDR_W  : integer := integer(ceil(log2(real(DEPTH))));
    
    type async_fifo_t is array (0 to DEPTH - 1) of std_logic_vector(WIDTH - 1 downto 0);
    signal fifo : async_fifo_t;

    signal wr_ptr_gray      : unsigned(ADDR_W - 1 downto 0);
    signal rd_ptr_gray      : unsigned(ADDR_W - 1 downto 0);

    
    signal wr_ptr           : unsigned(ADDR_W - 1 downto 0);
    signal rd_ptr           : unsigned(ADDR_W - 1 downto 0);
    signal wr_ptr_rd_clk_q  : unsigned(ADDR_W - 1 downto 0);
    signal rd_ptr_wr_clk_q  : unsigned(ADDR_W - 1 downto 0);
    signal wr_ptr_rd_clk    : unsigned(ADDR_W - 1 downto 0);
    signal rd_ptr_wr_clk    : unsigned(ADDR_W - 1 downto 0);
    
begin

    
    full    <= '1' when not(rd_ptr_wr_clk) = wr_ptr else '0';
    empty   <= '1' when wr_ptr_rd_clk = rd_ptr else '0';
    af      <= '1' when not(rd_ptr_wr_clk) = wr_ptr - AF_LEVEL else '0';
    ae      <= '1' when wr_ptr_rd_clk = rd_ptr + 1 else '0';
    -- Write pointer on write clock domain
    process (wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then
            wr_ptr      <= (others => '0');
            wr_ptr_gray <= (others => '0');
        elsif rising_edge(wr_clk) then
            if(wr_en = '1' and full  = '0') then
                wr_ptr <= wr_ptr + 1;
                wr_ptr_gray <= shift_right(wr_ptr + 1, 1) xor wr_ptr + 1;
            else
                wr_ptr <= wr_ptr;
            end if;
        end if;
    end process;

    -- Read pointer on read clock domain
    process (rd_clk, rd_rst_n)
    begin
        if rd_rst_n = '0' then
            rd_ptr      <= (others => '0');
            rd_ptr_gray <= (others => '0');
        elsif rising_edge(rd_clk) then
            if(rd_en = '1' and empty = '0') then
                rd_ptr <= rd_ptr + 1;
                rd_ptr_gray <= shift_right(rd_ptr + 1, 1) xor rd_ptr + 1;
            else
                rd_ptr <= rd_ptr;
            end if;
        end if;
    end process;

    -- 2FF sync for wr ptr to read domain
    process (rd_clk, rd_rst_n)
    begin
        if rd_rst_n = '0' then
            wr_ptr_rd_clk_q <= (others => '0');
            wr_ptr_rd_clk   <= (others => '0');
        elsif rising_edge(rd_clk) then
            wr_ptr_rd_clk_q <= wr_ptr_gray;
            wr_ptr_rd_clk   <= wr_ptr_rd_clk_q;
        end if;
    end process;

    -- 2FF sync for rd ptr to write domain
    process (wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then
            rd_ptr_wr_clk_q <= (others => '0');
            rd_ptr_wr_clk   <= (others => '0');
        elsif rising_edge(wr_clk) then
            rd_ptr_wr_clk_q <= rd_ptr_gray;
            rd_ptr_wr_clk   <= rd_ptr_wr_clk_q;
        end if;
    end process;

    -- Write data to FIFO process
    process(wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then

        elsif rising_edge(wr_clk) then
            if(wr_en = '1' and full = '0') then 
                fifo(to_integer(wr_ptr)) <= wr_data;
            end if;
        end if;
    end process;

    -- reading out data from fifo
    rd_data <= fifo(to_integer(rd_ptr)) when rd_en = '1' and empty = '0' else (others => '0');

end architecture;
