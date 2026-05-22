-- SCLK Generation, toggles once every 8 MCLK periods - Should be ~2.8MHz
    process(m_clk)
    begin
        if rising_edge(m_clk) then
            if RESET_N = '0' then
                s_clk <= '0';
                m_clk_cnt <= (others => '0');
            elsif m_clk_cnt = "011" then
                s_clk <= not s_clk;
                m_clk_cnt <= (others => '0');
            else
                m_clk_cnt <= m_clk_cnt + 1;
            end if;
        end if;
    end process;

    -- Right/Left Word Select, once every 64 SCLK periods - Should be ~44kHz
    process (s_clk, RESET_N)
    begin
        if RESET_N = '0' then 
            right_left_sel <= '0';
            s_clk_cnt <= (others => '0'); 
        elsif rising_edge(s_clk) then 
            if(s_clk_cnt = x"1F") then
                right_left_sel <= not right_left_sel;
                s_clk_cnt <= (others => '0'); 
            else 
                s_clk_cnt <= s_clk_cnt + 1;
            end if;
        end if;
    end process;
    
    
    process(m_clk, RESET_N)
    begin
        if RESET_N = '0' then 
            error <= '0';
            watchdog <= (others => '0'); 
        elsif rising_edge(m_clk) then
            if right_left_sel /= prev_right_left_sel then
                watchdog <= (others => '0');  -- reset on toggle
                error <= '0';
            else
                watchdog <= watchdog + 1;
                if watchdog = X"FFF" then
                    error <= '1';  -- LRCK hasn't toggled in too long
                end if;
            end if;
            prev_right_left_sel <= right_left_sel;
        end if;
    end process;


    DA_SDIN <= AD_SDOUT;
    DA_MCLK <= m_clk;
    AD_MCLK <= m_clk;
    DA_SCLK <= s_clk;
    AD_SCLK <= s_clk;
    DA_LRCK <= not right_left_sel;
    AD_LRCK <= not right_left_sel;