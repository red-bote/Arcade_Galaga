#!/bin/bash
# Create the initial Vivado Basys3 project for the Arcade_Galaga port, and
# copy the tracked port assets into place.
#
# Layout is non-nested: the .xpr lives directly in basys3/ and the project
# sources tree is basys3/arcade_galaga_basys3.srcs/.
#
# 1. Create the project dirs.
# 2. Copy arcade_galaga_basys3.xpr (authored with the local import paths, so
#    no re-pointing sed is needed).
# 3. Copy Basys-3-Master.xdc into constrs_1/imports/digilent-xdc-master/.
# 4. Copy mist/scandoubler.v into sources_1/imports/mist/ and apply the
#    Vivado-2020.2 parser fix to the copy only.
#
# clk_wiz_0 IP generation (make_clk_wiz_0.sh) and the top level are separate.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CONTRIB="$ROOT/contrib/basys3"

PROJ_DIR="$ROOT/basys3"
CONSTRS_IMPORT="$PROJ_DIR/arcade_galaga_basys3.srcs/constrs_1/imports/digilent-xdc-master"
SOURCES_IMPORT="$PROJ_DIR/arcade_galaga_basys3.srcs/sources_1/imports/mist"

if [ ! -f "$ROOT/rtl_dar/galaga.vhd" ]; then
    echo "error: upstream tree not found under: $ROOT" >&2
    exit 1
fi

step() { printf '\n==> %s\n' "$1"; }

step "1/4 Creating project directories"
mkdir -p "$PROJ_DIR" "$CONSTRS_IMPORT" "$SOURCES_IMPORT"

step "2/4 Copying arcade_galaga_basys3.xpr"
cp -f "$CONTRIB/vivado/arcade_galaga_basys3.xpr" "$PROJ_DIR/arcade_galaga_basys3.xpr"

step "3/4 Copying Basys-3-Master.xdc"
cp -f "$CONTRIB/vivado/Basys-3-Master.xdc" "$CONSTRS_IMPORT/Basys-3-Master.xdc"

step "4/4 Copying scandoubler.v (single-value array size -> full range)"
cp -f "$ROOT/mist/scandoubler.v" "$SOURCES_IMPORT/scandoubler.v"
# Vivado 2020.2 Verilog-2001 parser rejects the single-value unpacked array
# size 'sd_buffer[2*2**HCNT_WIDTH]' (Synth 8-2671); the pristine in-repo copy
# stays untouched, so apply the fix only to the imported instance.
(cd "$PROJ_DIR" && patch -p1 --forward < "$CONTRIB/../code/scandoubler_fix.patch")

echo
echo "Project files in place:"
ls -l "$PROJ_DIR/arcade_galaga_basys3.xpr"
ls -l "$CONSTRS_IMPORT/Basys-3-Master.xdc"
ls -l "$SOURCES_IMPORT/scandoubler.v"
