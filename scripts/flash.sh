#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OPENOCD="$ROOT/dist/openocd-macos-arm64-hid/bin/openocd-macos-arm64-hid"
SCRIPTS="$ROOT/dist/openocd-macos-arm64-hid/share/openocd/scripts"
ELF=${1:-"$ROOT/examples/gpio_toggle.out"}

if [ ! -x "$OPENOCD" ]; then
    echo "OpenOCD not found: $OPENOCD" >&2
    exit 1
fi
if [ ! -f "$ELF" ]; then
    echo "ELF not found: $ELF" >&2
    exit 1
fi

exec env OPENOCD_SCRIPTS="$SCRIPTS" "$OPENOCD" \
    -f interface/cmsis-dap.cfg \
    -f target/ti_mspm0.cfg \
    -c "adapter speed 2000" \
    -c "program {$ELF} verify reset exit"
