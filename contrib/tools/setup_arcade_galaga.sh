#!/bin/bash
# Setup for the Arcade_Galaga Basys3 port, then chain into rom-prep.
#
# Unlike the other machines there is no download/extract step: the upstream
# tree (Somhi's Arcade_Galaga) is checked into the repo and IS this machine
# directory. This script sanity-checks key sources, applies the Vivado parser
# fix to mist/scandoubler.v, and runs contrib/tools/prep_roms.sh.
#
# Roms and the generated PROM VHDL stay local (never distributed).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

for f in \
    rtl_dar/galaga.vhd \
    rtl_dar/galaga_de10_lite.vhd \
    rtl_dar/kbd_joystick.vhd \
    rtl_T80/T80se.vhd \
    mist/scandoubler.v \
    tools/galaga_unzip/make_galaga_proms.bat ; do
    if [ ! -f "$ROOT/$f" ]; then
        echo "error: expected in-repo upstream file missing: $ROOT/$f" >&2
        exit 1
    fi
done

printf '==> Upstream Arcade_Galaga tree verified in place\n'

printf '==> Applying Vivado parser fix to mist/scandoubler.v\n'
(cd "$ROOT" && patch -p1 --forward < contrib/code/scandoubler_fix.patch)

printf '==> Promoting dip-switch ports from hard-coded to entity-level on rtl_dar/galaga.vhd\n'
(cd "$ROOT" && patch -p1 --forward < contrib/code/galaga_dipswitch.patch)

exec "$ROOT/contrib/tools/prep_roms.sh"
