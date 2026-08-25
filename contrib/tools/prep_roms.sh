#!/bin/bash
# Linux rom-prep for the Arcade_Galaga Basys3 port.
#
# 1. Compile make_vhdl_prom from the in-repo Somhi source tree on the host (gcc).
# 2. Convert make_galaga_proms.bat -> make_galaga_proms.sh (the shipped .sh has
#    CRLF endings and is bash-hostile; the conversion also strips \r).
# 3. Unzip the two romsets (~/roms/galaga.zip + ~/roms/galagamw.zip) into
#    tools/galaga_unzip/. The plain galaga set provides the palette/sound PROMs
#    and 54xx.bin but names its CPU/graphix ROMs gg1_* — the 3200a-3700g /
#    2600j / 2800l / 2700k bins come from the galagamw set.
# 4. Run make_galaga_proms.sh to generate the PROM VHDL, referenced in place
#    by arcade_galaga_basys3.xpr ($PPRDIR/../tools/galaga_unzip/*.vhd).
#
# Roms and the generated PROM VHDL are copyrighted MAME-derived content:
# never commit or distribute them.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROM_DIR="$ROOT/tools/galaga_unzip"
TOOLS_SRC="$ROOT/tools/tools_prom_src/src"

ROMZIP1="${ROMZIP1:-$HOME/roms/galaga.zip}"
ROMZIP2="${ROMZIP2:-$HOME/roms/galagamw.zip}"

step() { printf '\n==> %s\n' "$1"; }

if [ ! -f "$TOOLS_SRC/make_vhdl_prom.c" ]; then
    echo "error: prom tool sources not found: $TOOLS_SRC" >&2
    exit 1
fi

mkdir -p "$PROM_DIR"

step "1/4 Compiling make_vhdl_prom on the host"
gcc "$TOOLS_SRC/make_vhdl_prom.c" -lm -o "$PROM_DIR/make_vhdl_prom"

step "2/4 Converting make_galaga_proms.bat to .sh"
if [ ! -f "$PROM_DIR/make_galaga_proms.bat" ]; then
    echo "error: $PROM_DIR/make_galaga_proms.bat not found" >&2
    exit 1
fi

sed -E \
    -e 's/\r$//' \
    -e 's/^copy \/B (.*) ([^ ]+)$/cat \1 > \2/' \
    -e 's/ \+ / /g' \
    -e 's/^make_vhdl_prom /.\/make_vhdl_prom /' \
    -e 's/^del /rm /' \
    "$PROM_DIR/make_galaga_proms.bat" > "$PROM_DIR/make_galaga_proms.sh"
chmod +x "$PROM_DIR/make_galaga_proms.sh"

step "3/4 Unzipping romsets"
unzip -o "$ROMZIP1" -d "$PROM_DIR"
unzip -o "$ROMZIP2" -d "$PROM_DIR"

step "4/4 Generating PROM VHDL"
( cd "$PROM_DIR" && ./make_galaga_proms.sh )

echo
echo "Rom-prep complete. PROM VHDL generated in:"
ls -1 "$PROM_DIR"/*.vhd
