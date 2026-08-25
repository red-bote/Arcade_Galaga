#!/bin/bash
# Generate the patch that adapts the upstream DE10-lite top level
# (rtl_dar/galaga_de10_lite.vhd) into the Basys3 top level
# (arcade_galaga_basys3.vhd).
#
# The target arcade_galaga_basys3.vhd is authored here (it is a full rewrite of
# the top-level wrapper; note that Somhi's DE10-lite top is stale — see
# PORTING_SPEC.md §7.1 — and serves only as the diff base). The script:
#   1. Writes the target VHDL to a scratch dir.
#   2. Diffs it against the pristine upstream source to produce the git-style
#      patch at contrib/basys3/code/galaga_de10_lite_to_basys3.patch.
#   3. Places the target where arcade_galaga_basys3.xpr expects it
#      (basys3/arcade_galaga_basys3.srcs/sources_1/new/arcade_galaga_basys3.vhd).
#
# The upstream tree is checked in, so no setup step is required for this script.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$ROOT/rtl_dar/galaga_de10_lite.vhd"
PROJ_DIR="$ROOT/basys3"
TARGET_SRC="$PROJ_DIR/arcade_galaga_basys3.srcs/sources_1/new"
PATCH="$ROOT/contrib/basys3/code/galaga_de10_lite_to_basys3.patch"

WORK=/tmp/arcade_galaga_de10_to_basys3
TARGET="$WORK/arcade_galaga_basys3.vhd"

if [ ! -f "$SRC" ]; then
    echo "error: pristine source not found: $SRC" >&2
    exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TARGET" <<'EOF'
---------------------------------------------------------------------------------
-- Basys3 Top level for Galaga (Namco, 1981) — Somhi's Arcade_Galaga tree,
-- adapted from Dar's DE10-lite core.
--
-- Ported from galaga_de10_lite.vhd per Arcade_Galaga/PORTING_SPEC.md:
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 36 MHz
--  - Atari-style joystick on JA, OR-merged with PS/2 keyboard (JB)
--    (Somhi kbd_joystick: arrows/space; F3 coin, F4 start1, F5 start2)
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--  - 31 kHz VGA on the Basys3 VGA connector via MiST scandoubler (patched in-place at mist/);
--    F8 key toggles to 15 kHz TV (native RGB + composite sync on HS)
--  - btnC = reset (core also held in reset while the MMCM unlocks)
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity arcade_galaga_basys3 is
port(
 clk            : in  std_logic;
 sw             : in  std_logic_vector(15 downto 0);
 btnC           : in  std_logic;

 JA             : in  std_logic_vector(4 downto 0);  -- joystick
 ps2_dat        : in  std_logic;
 ps2_clk        : in  std_logic;

 O_PMODAMP2_AIN : out std_logic;
 O_PMODAMP2_GAIN: out std_logic;
 O_PMODAMP2_SHUTD: out std_logic;

 vga_r : out std_logic_vector(3 downto 0);
 vga_g : out std_logic_vector(3 downto 0);
 vga_b : out std_logic_vector(3 downto 0);
 vga_hs: out std_logic;
 vga_vs: out std_logic
);
end arcade_galaga_basys3;

architecture struct of arcade_galaga_basys3 is

 signal clock_36 : std_logic;
 signal clock_18 : std_logic;
 signal clock_9  : std_logic;
 signal clock_12 : std_logic;
 signal clock_6  : std_logic;
 signal slot     : std_logic_vector(2 downto 0);
 signal reset    : std_logic;
 signal mmcm_locked : std_logic;
 signal tv15Khz_mode : std_logic;

 signal r         : std_logic_vector(2 downto 0);
 signal g         : std_logic_vector(2 downto 0);
 signal b         : std_logic_vector(1 downto 0);
 signal csync     : std_logic;
 signal blankn    : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(9 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal vga_r_i  : std_logic_vector(5 downto 0);
 signal vga_g_i  : std_logic_vector(5 downto 0);
 signal vga_b_i  : std_logic_vector(5 downto 0);
 signal vga_r_o  : std_logic_vector(5 downto 0);
 signal vga_g_o  : std_logic_vector(5 downto 0);
 signal vga_b_o  : std_logic_vector(5 downto 0);
 signal hsync_o  : std_logic;
 signal vsync_o  : std_logic;

 signal kbd_intr     : std_logic;
 signal kbd_scancode : std_logic_vector(7 downto 0);

 -- Somhi kbd_joystick interface. fn_toggle(7) (F8 key) drives the display
 -- mode (tv15Khz_mode). The remaining bits are self-read inside the entity
 -- (falling-edge toggles), so the signal must be initialized.
 signal joy_BBBBFRLDU : std_logic_vector(8 downto 0) := (others => '0');
 signal fn_pulse      : std_logic_vector(7 downto 0) := (others => '0');
 signal fn_toggle     : std_logic_vector(7 downto 0) := (others => '0');

 -- keyboard contributions to the merged player inputs
 signal kb_left   : std_logic;
 signal kb_right  : std_logic;
 signal kb_fire   : std_logic;
 signal kb_start1 : std_logic;
 signal kb_start2 : std_logic;
 signal kb_coin   : std_logic;

 component scandoubler
     port (
         clk_sys   : in  std_logic;
         scanlines : in  std_logic_vector (1 downto 0);
         ce_x1     : in  std_logic;
         ce_x2     : in  std_logic;
         hs_in     : in  std_logic;
         vs_in     : in  std_logic;
         r_in      : in  std_logic_vector (5 downto 0);
         g_in      : in  std_logic_vector (5 downto 0);
         b_in      : in  std_logic_vector (5 downto 0);
         hs_out    : out std_logic;
         vs_out    : out std_logic;
         r_out     : out std_logic_vector (5 downto 0);
         g_out     : out std_logic_vector (5 downto 0);
         b_out     : out std_logic_vector (5 downto 0)
     );
 end component;

begin

reset <= btnC or not mmcm_locked;

-- Clock 36MHz for the core clock chain and the scan doubler's clock divider.
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_36,
 reset    => btnC,          -- MMCM reset active-high from the button
 locked   => mmcm_locked
);

-- Halve clock_36 to clock_18 for the galaga core (36/2).
process (reset, clock_36)
begin
	if reset='1' then
		clock_18  <= '0';
	else
		if rising_edge(clock_36) then
				clock_18  <= not clock_18;
		end if;
	end if;
end process;

-- Galaga
galaga : entity work.galaga
port map(
 clock_18     => clock_18,
 reset        => reset,

 video_r      => r,
 video_g      => g,
 video_b      => b,
 video_csync  => csync,
 video_blankn => blankn,
 video_hs     => hsync,
 video_vs     => vsync,
 audio        => audio,

 b_test       => '1',
 b_svce       => '1',

 coin         => kb_coin   or (not JA(4) and not JA(3)),
 start1       => kb_start1 or (not JA(4) and not JA(1)),
 left1        => kb_left   or  not JA(1),
 right1       => kb_right  or  not JA(0),
 fire1        => kb_fire   or  not JA(4),
 start2       => kb_start2 or (not JA(4) and not JA(0)),
 left2        => kb_left   or  not JA(1),
 right2       => kb_right  or  not JA(0),
 fire2        => kb_fire   or  not JA(4),

 -- Dip switches: inverted polarity so all-down = normal defaults (sw12..sw0)
 -- sw12=cab(Upright/Cocktail) sw11=Test sw10=Freeze sw9=DemoSound
 -- sw8:7=Difficulty sw6:5=Lives sw4:2=Bonus sw1:0=reserved
 dip_switch_a => sw(12) & '1' & not sw(11) & not sw(10) & not sw(9) & '1' & sw(8 downto 7),
 dip_switch_b => sw(6 downto 5) & sw(4 downto 2) & "111"
);

-- 31 kHz VGA via the MiST scandoubler (patched in-place at mist/).
-- Pad the core's 3/3/2-bit RGB to 6 bits by MSB replication; force black during blank.
vga_r_i <= r & r     when blankn = '1' else "000000";
vga_g_i <= g & g     when blankn = '1' else "000000";
vga_b_i <= b & b & b when blankn = '1' else "000000";

-- Derive the scandoubler clocks: clock_12 (clk_sys) and clock_6 (ce_x1) from a
-- mod-6 counter clocked by clock_36 (see PORTING_SPEC 12.3).
process (clock_36)
begin
    if rising_edge(clock_36) then
        clock_12 <= '0';
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

scandoubler_inst : scandoubler
port map(
 clk_sys   => clock_12,
 scanlines => "00",
 ce_x1     => clock_6,
 ce_x2     => '1',
 hs_in     => hsync,
 vs_in     => vsync,
 r_in      => vga_r_i,
 g_in      => vga_g_i,
 b_in      => vga_b_i,
 hs_out    => hsync_o,
 vs_out    => vsync_o,
 r_out     => vga_r_o,
 g_out     => vga_g_o,
 b_out     => vga_b_o
);

-- Display mode toggle via F8 key (fn_toggle(7)):
--   0 = 31 kHz VGA (scan-doubled 6-bit RGB adapted to 4bits/color)
--   1 = 15 kHz TV  (native core RGB padded to 4bits, composite sync on HS,
--       VS held high -- requires a 15 kHz RGB monitor or RGB->composite converter)
tv15Khz_mode <= fn_toggle(7);          -- F8 key

process (clock_36)
begin
    if rising_edge(clock_36) then
        if tv15Khz_mode = '1' then
            -- RGB (15 kHz TV)
            if blankn = '1' then
                vga_r  <= r & '0';
                vga_g  <= g & '0';
                vga_b  <= b & "00";
            else
                vga_r  <= "0000";
                vga_g  <= "0000";
                vga_b  <= "0000";
            end if;
            vga_hs <= csync;
            vga_vs <= '1';
        else
            -- VGA (31 kHz, scan-doubled)
            vga_r  <= vga_r_o(5 downto 2);
            vga_g  <= vga_g_o(5 downto 2);
            vga_b  <= vga_b_o(5 downto 2);
            vga_hs <= hsync_o;
            vga_vs <= vsync_o;
        end if;
    end if;
end process;

-- get scancode from keyboard
process (reset, clock_18)
begin
	if reset='1' then
		clock_9  <= '0';
	else
		if rising_edge(clock_18) then
				clock_9  <= not clock_9;
		end if;
	end if;
end process;

keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_9, -- synchronous clock with core
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick (Somhi interface: arrows/space +
-- F-key pulse/toggle banks)
joystick : entity work.kbd_joystick
port map (
  Clk           => clock_9, -- synchronous clock with core
  KbdInt        => kbd_intr,
  KbdScanCode   => kbd_scancode,
  joy_BBBBFRLDU => joy_BBBBFRLDU,
  fn_pulse      => fn_pulse,
  fn_toggle     => fn_toggle
);

-- Keyboard mapping (see PORTING_SPEC 7.1): left/right/fire from the joy bits,
-- coin/start via the F-keys exactly as Somhi's working deca top wires them
-- (his inline comments say F1/F2 for start1/start2 but the scancode constants
-- are F4/F5).
kb_left   <= joy_BBBBFRLDU(2);  -- left arrow  (0x6B)
kb_right  <= joy_BBBBFRLDU(3);  -- right arrow (0x74)
kb_fire   <= joy_BBBBFRLDU(4);  -- space       (0x29)
kb_start1 <= fn_pulse(3);       -- F4 (0x0C)
kb_start2 <= fn_pulse(4);       -- F5 (0x03)
kb_coin   <= fn_pulse(2);       -- F3 (0x04)

-- pwm sound output
process(clock_18)  -- same clock as the DE10 top drove the PWM accumulator
begin
  if rising_edge(clock_18) then
    pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "000"));
  end if;
end process;

O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
EOF

# Emit git-style patch (matches the *_de10_lite_to_basys3.patch convention).
{
  printf 'diff --git a/rtl_dar/galaga_de10_lite.vhd b/rtl_dar/galaga_de10_lite.vhd\n'
  diff -u --label "a/rtl_dar/galaga_de10_lite.vhd" \
            --label "b/rtl_dar/galaga_de10_lite.vhd" \
            "$SRC" "$TARGET" || [ $? -eq 1 ]   # diff returns 1 when files differ (expected)
} > "$PATCH"

mkdir -p "$TARGET_SRC"
cp -f "$TARGET" "$TARGET_SRC/arcade_galaga_basys3.vhd"

rm -rf "$WORK"

echo "Generated patch:  $PATCH"
echo "Placed target:    $TARGET_SRC/arcade_galaga_basys3.vhd"
echo "Verify with:      patch -p1 --dry-run < contrib/basys3/code/galaga_de10_lite_to_basys3.patch"
