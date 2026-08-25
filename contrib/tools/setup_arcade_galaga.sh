#!/bin/bash
# Setup for the Arcade_Galaga Basys3 port, then chain into rom-prep.
#
# Unlike the other machines there is no download/extract step: the upstream
# tree (Somhi's Arcade_Galaga) is checked into the repo and IS this machine
# directory. This script only sanity-checks key sources and runs
# contrib/tools/prep_roms.sh.
#
# No fix patches are applied to the pristine tree: Somhi's fork already
# contains all three galaga.vhd fixes the Midway port needed (video_hs/vs
# wiring, credit mode, bgpalette xor shape — see PORTING_SPEC.md §8). The only
# patch, scandoubler_fix.patch, is applied later by create_project.sh to the
# imported copy of mist/scandoubler.v, never to the pristine tree.
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

exec "$ROOT/contrib/tools/prep_roms.sh"
