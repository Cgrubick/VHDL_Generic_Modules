library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


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

    type async_fifo_t is array (0 to DEPTH - 1) of std_logic_vector(WIDTH - 1 downto 0);
    signal fifo : async_fifo_t;

    signal wr_ptr_gray      : unsigned(WIDTH - 1 downto 0);
    signal rd_ptr_gray      : unsigned(WIDTH - 1 downto 0);

    
    signal wr_ptr           : unsigned(WIDTH - 1 downto 0);
    signal rd_ptr           : unsigned(WIDTH - 1 downto 0);
    signal wr_ptr_rd_clk_q  : unsigned(WIDTH - 1 downto 0);
    signal rd_ptr_wr_clk_q  : unsigned(WIDTH - 1 downto 0);
    signal wr_ptr_rd_clk    : unsigned(WIDTH - 1 downto 0);
    signal rd_ptr_wr_clk    : unsigned(WIDTH - 1 downto 0);
    
begin

    full    <= '1' when rd_ptr_wr_clk = wr_ptr else '0';
    empty   <= '1' when wr_ptr_rd_clk = rd_ptr else '0';
    ae      <= '1';
    af      <= '1';
    -- Write pointer on write clock domain
    process (wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then
            
        elsif rising_edge(wr_clk) then
            if(wr_en and not full) then
                wr_ptr <= wr_ptr + 1;
            else
                wr_ptr <= wr_ptr;
            end if;
        end if;
    end process;

    -- Read pointer on read clock domain
    process (rd_clk, rd_rst_n)
    begin
        if rd_rst_n = '0' then
            
        elsif rising_edge(rd_clk) then
            if(rd_en and not empty) then
                rd_ptr <= rd_ptr + 1;
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
            wr_ptr_rd_clk_q <= wr_ptr;
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
            rd_ptr_wr_clk_q <= rd_ptr;
            rd_ptr_wr_clk   <= rd_ptr_wr_clk_q;
        end if;
    end process;

    -- Write data to FIFO process
    process(wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then

        elsif rising_edge(wr_clk) then
            if(wr_en and not full) then 
                fifo(to_integer(wr_ptr)) <= wr_data;
            end if;
        end if;
    end process;

    -- reading out data from fifo
    rd_data <= fifo(to_integer(rd_ptr)) when rd_en and not empty else (others => '0');

end architecture;
