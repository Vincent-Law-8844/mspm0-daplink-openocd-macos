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


# Known MuseLab DAPLink issue: keeping its CDC UART open while programming can
# make the MSPM0 flash controller lose the AP. Refuse to flash in that case.
if command -v lsof >/dev/null 2>&1; then
    if lsof /dev/cu.usbmodem* 2>/dev/null | grep -q .; then
        echo "ERROR: a /dev/cu.usbmodem* serial port is open." >&2
        echo "Close the DAPLink UART / serial monitor before flashing." >&2
        exit 1
    fi
fi

exec env OPENOCD_SCRIPTS="$SCRIPTS" "$OPENOCD" \
    -f interface/cmsis-dap.cfg \
    -f target/ti_mspm0.cfg \
    -c "adapter speed 2000" \
    -c "program {$ELF} verify reset exit"
