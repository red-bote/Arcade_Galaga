# Arcade Galaga (Basys 3 port by Red-Bote)

Port of **Somhi's Arcade_Galaga** FPGA implementation of Namco's Galaga (1981)
hardware — adapted by Somhi (DECAfpga) from Dar's DE10-lite core — to the
Digilent Basys 3. The machine directory *is* the checked-in upstream tree
(`rtl_dar/`, `rtl_T80/`, `mist/`, tools, and Somhi's board variants under
their own subdirectories).

- Upstream: <https://github.com/DECAfpga/Arcade_Galaga>; original core:
  Dar (<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/galaga/>)
- Project / top entity: `basys3/arcade_galaga_basys3.xpr`, `arcade_galaga_basys3`
- Clocking: `clk_wiz_0` MMCM 100 MHz → 36 MHz (`DIVCLK_DIVIDE=5`,
  `CLKFBOUT_MULT_F=49.5`, `CLKOUT0_DIVIDE_F=27.5`); core clocked at 18 MHz
  (36 ÷ 2), keyboard logic at 9 MHz
- Video: MiST `scandoubler.v` (upstream already fixed) → 31 kHz
  progressive VGA; F8 key (`fn_toggle(7)`) selects 15 kHz TV mode (native
  rate, composite sync on HS)
- Design details and porting decisions: [PORTING_SPEC.md](PORTING_SPEC.md)

## Features supported

- Full Namco Galaga hardware: 3× Z80 (T80 cores), custom logic, Namco WSG
  audio, star field generator
- PS/2 keyboard OR-merged with an Atari-style joystick on JA
- Mono PWM audio on PmodAMP2 (JC)
- Two display modes selected by F8 key (`fn_toggle(7)`)
- Reset via `btnC` (core also held in reset while the MMCM unlocks)

## IO mapping

| Basys 3 | Function | Notes |
|---|---|---|
| `clk` (W5) | 100 MHz oscillator | into `clk_wiz_0` |
| `btnC` | reset | active-high |
| `btnU` | coin | active-high |
| `btnD` | coin | active-high |
| `btnL` | start 1 player | active-high |
| `btnR` | start 2 players | active-high |
| `sw(15)` | `O_PMODAMP2_GAIN` | AMP gain: 0 = 12 dB, 1 = 6 dB |
| `sw(14)` | `O_PMODAMP2_SHUTD` | AMP shutdown: 0 = off, 1 = on |
| `sw(12)` | Cabinet | UP = upright, DOWN = cocktail |
| `sw(11)` | Test mode | UP = off (normal), DOWN = on |
| `sw(10)` | Freeze | UP = off (normal), DOWN = on |
| `sw(9)` | Demo sound | UP = off, DOWN = on (normal) |
| `sw(8:7)` | Difficulty | UP/UP = normal (see PORTING_SPEC §7.3) |
| `sw(6:5)` | Lives | DOWN/DOWN = 2 lives (normal) |
| `sw(4:2)` | Bonus | DOWN/DOWN/DOWN = 10k (normal) |
| `sw(1:0)` | Reserved | Tied to '1' |
| F8 key (`fn_toggle(7)`) | display mode | 0 = 31 kHz VGA, 1 = 15 kHz TV (csync on HS) |
| `JA(0..4)` | joystick right/left/down/up/fire (JA1–4, JA7) | active-low (switch to GND); combos: fire+left = start1, fire+right = start2, fire+up = coin |
| `ps2_dat`/`ps2_clk` (JB) | PS/2 keyboard | key map below |
| JC1/JC2/JC4 | `O_PMODAMP2_AIN`/`GAIN`/`SHUTD` | PWM audio out |
| VGA connector | `vga_r/g/b(3:0)`, `vga_hs`, `vga_vs` | 4-4-4 RGB |

## Keyboard

Arrows move, Space fires; **F3** adds a coin, **F4** starts 1 player, **F5**
starts 2 players (the `fn_pulse` path, wired exactly as Somhi's working
`deca_lcd` top does — his inline comments mislabel two of these keys; the
scancodes are authoritative, see PORTING_SPEC §7.1). The `f`/`g`/`t`/`v` keys
map to spare joystick bits unused by this core.

## Scripted setup

No download step — the upstream tree is checked in and *is* this directory.
From here:

```
make setup         # tree sanity check, detect-and-skip patches, then prep_roms
make create_prj    # stage .xpr / XDC, import galaga.vhd → sources_1/imports/
make clk_wiz       # generate the clk_wiz_0 MMCM IP (Vivado batch, from /tmp)
make patch         # author/place the arcade_galaga_basys3.vhd top level
make synth         # synthesis only; or: make bitstream
```

`prep_roms.sh` compiles `make_vhdl_prom`, regenerates `make_galaga_proms.sh`
(LF) from the shipped `.bat`, unzips both romsets into `tools/galaga_unzip/`,
and generates the PROM VHDL referenced in place by the project. Romsets
resolve as `$ROMZIP1` → `~/roms/galaga.zip` and `$ROMZIP2` →
`~/roms/galagamw.zip`.

## Rom set required

Two sets — the plain `galaga` set names its CPU/graphix ROMs `gg1_*` and does
not provide the files the generator expects:

- `~/roms/galaga.zip` — `prom-1.1d/2.5c/3.1c/4.2n/5.5n`, `54xx.bin`
- `~/roms/galagamw.zip` — `3200a`–`3700g` CPU ROMs, `2600j`/`2800l`/`2700k`

Roms and the generated PROM VHDL are copyrighted content — never commit or
distribute them.

## Known issues

- The Dar-core keyboard can randomly stick left/right — known upstream issue,
  also documented on the Galaga Midway port.
- TV mode requires a 15 kHz RGB monitor or an RGB→composite converter; a
  standard VGA LCD will not sync.
- `rtl_dar/galaga_de10_lite.vhd` is stale against Somhi's own `kbd_joystick`
  entity and does not compile; it is kept only as the diff base for the
  recorded top-level rewrite patch (PORTING_SPEC §7.1).


