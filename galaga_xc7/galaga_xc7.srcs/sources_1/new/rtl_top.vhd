----------------------------------------------------------------------------------
-- Company: Red~Bote
-- Engineer: Glenn Neidermeier
-- 
-- Create Date: 09/28/2024 07:10:59 AM
-- Design Name: 
-- Module Name: rtl_top - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
--  Basys 3 top level for Galaga adapted from:
--  DE10_lite Top level for Galaga Midway by Dar (darfpga@aol.fr) (06/11/2017)
--  http://darfpga.blogspot.fr
--  ports for Galaga by Somhi adapted from DE10_lite port by Dar (https://sourceforge.net/projects/darfpga/files/Software%20VHDL/galaga/)
--  https://github.com/DECAfpga/Arcade_Galaga
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;


entity rtl_top is
    port (
        clk : in std_logic;

        btnC : in std_logic;
        btnU : in std_logic;
        btnL : in std_logic;
        btnR : in std_logic;
        btnD : in std_logic;

        sw : in std_logic_vector (15 downto 0);

        JA : in std_logic_vector(4 downto 0);

        O_PMODAMP2_AIN : out std_logic;
        O_PMODAMP2_GAIN : out std_logic;
        O_PMODAMP2_SHUTD : out std_logic;

        vgaRed : out std_logic_vector (3 downto 0);
        vgaGreen : out std_logic_vector (3 downto 0);
        vgaBlue : out std_logic_vector (3 downto 0);
        Hsync : out std_logic;
        Vsync : out std_logic;
        led : out std_logic_vector (15 downto 0));
end rtl_top;

architecture rtl of rtl_top is

    signal clock_36 : std_logic;
    signal clock_6 : std_logic;
    signal clock_12 : std_logic;

    signal clock_18 : std_logic;
    signal reset : std_logic;

    signal r : std_logic_vector(2 downto 0);
    signal g : std_logic_vector(2 downto 0);
    signal b : std_logic_vector(1 downto 0);
    signal csync : std_logic;
    signal blankn : std_logic;
    signal hsync_x1 : std_logic;
    signal vsync_x1 : std_logic;

    signal audio : std_logic_vector(9 downto 0);
    signal pwm_accumulator : std_logic_vector(12 downto 0);

    -- alias reset_n         : std_logic is SW2;

    signal joyPCFRLDU : std_logic_vector(8 downto 0);
    signal fn_pulse : std_logic_vector(7 downto 0);

    signal video_clk : std_logic;
    signal vga_g_i : std_logic_vector(5 downto 0);
    signal vga_r_i : std_logic_vector(5 downto 0);
    signal vga_b_i : std_logic_vector(5 downto 0);
    signal vga_r_o : std_logic_vector(5 downto 0);
    signal vga_g_o : std_logic_vector(5 downto 0);
    signal vga_b_o : std_logic_vector(5 downto 0);
    signal hsync_o : std_logic;
    signal vsync_o : std_logic;

    -- joy signals
    signal left_i : std_logic;
    signal right_i : std_logic;
    -- signal up_i            : std_logic;
    -- signal down_i          : std_logic;
    signal fire_i : std_logic;

    component scandoubler -- mod by somhic
        port (
            clk_sys : in std_logic;
            scanlines : in std_logic_vector (1 downto 0);
            ce_x1 : in std_logic;
            ce_x2 : in std_logic;
            hs_in : in std_logic;
            vs_in : in std_logic;
            r_in : in std_logic_vector (5 downto 0);
            g_in : in std_logic_vector (5 downto 0);
            b_in : in std_logic_vector (5 downto 0);
            hs_out : out std_logic;
            vs_out : out std_logic;
            r_out : out std_logic_vector (5 downto 0);
            g_out : out std_logic_vector (5 downto 0);
            b_out : out std_logic_vector (5 downto 0)
        );
    end component;

    signal slot : std_logic_vector(2 downto 0) := (others => '0');

    component clk_wiz_0
        port (-- Clock in ports
            -- Clock out ports
            clk_out1 : out std_logic;
            -- Status and control signals
            locked : out std_logic;
            clk_in1 : in std_logic
        );
    end component;

begin

    --reset_n <= '1';
    reset <= '0'; -- not reset_n;

    clk_11_18 : clk_wiz_0
    port map(
        -- Clock out ports  
        clk_out1 => clock_36,
        -- Status and control signals
        locked => open,
        -- Clock in ports
        clk_in1 => clk
    );

    process (clock_36)
    begin
        if rising_edge(clock_36) then
            clock_12 <= '0';

            clock_18 <= not clock_18;

            if slot = "101" then
                slot <= (others => '0');
            else
                slot <= std_logic_vector(unsigned(slot) + 1);
            end if;

            if slot = "100" or slot = "001" then
                clock_6 <= not clock_6;
            end if;
            if slot = "100" or slot = "001" then
                clock_12 <= '1';
            end if;

        end if;
    end process;

    -- Galaga
    galaga : entity work.galaga
        port map(
            clock_18 => clock_18,
            reset => reset,

            -- tv15Khz_mode => tv15Khz_mode,
            video_r => r,
            video_g => g,
            video_b => b,
            video_csync => csync,
            video_blankn => blankn,
            video_hs => hsync_x1,
            video_vs => vsync_x1,
            video_clk => video_clk, -- mod by somhic
            audio => audio,

            b_test => '1',
            b_svce => '1',
            coin => btnU or btnD or btnL or btnR, -- not JA(4) and not JA(3), -- fn_pulse(2), -- F3
            start1 => not JA(4) and not JA(1), -- fn_pulse(3), -- F1
            start2 => fn_pulse(4), -- F2

            left1 => not JA(1), -- not left_i,   --joyPCFRLDU(2),
            right1 => not JA(0), -- not right_i,  --joyPCFRLDU(3),
            fire1 => not JA(4), -- not fire_i,   --joyPCFRLDU(4),

            left2 => joyPCFRLDU(2),
            right2 => joyPCFRLDU(3),
            fire2 => joyPCFRLDU(4)
        );

    -- adapt video to 6 bits/color only
    vga_r_i <= r & r when blankn = '1' else "000000";
    vga_g_i <= g & g when blankn = '1' else "000000";
    vga_b_i <= b & b & b when blankn = '1' else "000000";

    -- vga scandoubler
    scandoubler_inst : scandoubler
    port map(
        clk_sys => clock_12, --clock_18, video_clk i clock_36 no funciona
        scanlines => "00", --(00-none 01-25% 10-50% 11-75%)
        ce_x1 => clock_6,
        ce_x2 => '1',
        hs_in => hsync_x1,
        vs_in => vsync_x1,
        r_in => vga_r_i,
        g_in => vga_g_i,
        b_in => vga_b_i,
        hs_out => hsync_o,
        vs_out => vsync_o,
        r_out => vga_r_o,
        g_out => vga_g_o,
        b_out => vga_b_o
    );

    --VGA
    -- adapt video to 4 bits/color only
    vgaRed <= vga_r_o (5 downto 2);
    vgaGreen <= vga_g_o (5 downto 2);
    vgaBlue <= vga_b_o (5 downto 2);
    Hsync <= hsync_o;
    Vsync <= vsync_o;

    -- pwm sound output
    process (clock_18)
    begin
        if rising_edge(clock_18) then
            pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio & '0'));
        end if;
    end process;

    -- active-low shutdown pin
    O_PMODAMP2_SHUTD <= sw(14);
    -- gain pin is driven high there is a 6 dB gain, low is a 12 dB gain 
    O_PMODAMP2_GAIN <= sw(15);

    --pwm_audio_out_l <= pwm_accumulator(12);
    --pwm_audio_out_r <= pwm_accumulator(12);
    O_PMODAMP2_AIN <= pwm_accumulator(12);

end rtl;
