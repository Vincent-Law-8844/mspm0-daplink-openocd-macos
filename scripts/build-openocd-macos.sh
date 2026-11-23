#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PREFIX="$ROOT/dist/openocd-macos-arm64-hid"
SRC="$ROOT/build/ti-openocd-src"
COMMIT=47bf6076181862fe3d7509f4aa49c27dc10f7730

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "missing: $1" >&2
        echo "install with: brew install autoconf automake libtool pkg-config libusb hidapi libftdi capstone" >&2
        exit 1
    }
}

need git
need autoconf
need automake
need pkg-config
if ! command -v libtoolize >/dev/null 2>&1 && ! command -v glibtoolize >/dev/null 2>&1; then
    echo "missing: libtoolize (brew install libtool)" >&2
    exit 1
fi

mkdir -p "$ROOT/build" "$PREFIX"

if [ ! -d "$SRC/.git" ]; then
    echo "== cloning ti-openocd"
    git clone https://github.com/TexasInstruments/ti-openocd.git "$SRC"
fi

if ! git -C "$SRC" cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
    git -C "$SRC" fetch --depth 1 origin "$COMMIT"
fi
git -C "$SRC" checkout -f "$COMMIT"
git -C "$SRC" submodule update --init --depth 1 jimtcl

PATCH="$ROOT/patches/mspm0-batch-ap-writes.patch"
if git -C "$SRC" apply --check "$PATCH" 2>/dev/null; then
    git -C "$SRC" apply "$PATCH"
    echo "== applied mspm0 batch AP write patch"
elif git -C "$SRC" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "== mspm0 batch AP write patch already applied"
else
    echo "ERROR: could not apply $PATCH" >&2
    exit 1
fi

cd "$SRC"
BREW_PREFIX=$(brew --prefix 2>/dev/null || echo /opt/homebrew)
export ACLOCAL_PATH="$BREW_PREFIX/share/aclocal${ACLOCAL_PATH:+:$ACLOCAL_PATH}"
export CCACHE_DISABLE=1
export CC=cc
export CXX=c++

./bootstrap nosubmodule
./configure \
    --prefix="$PREFIX" \
    --enable-cmsis-dap \
    --enable-cmsis-dap-v2 \
    --enable-xds110 \
    --disable-jlink \
    --disable-ftdi \
    --disable-stlink \
    --disable-doxygen-html \
    --disable-werror

make -j"$(sysctl -n hw.ncpu)"
make install

# keep the distribution lean: OpenOCD only needs bin + scripts
rm -rf "$PREFIX/share/man" "$PREFIX/share/info" "$PREFIX/share/openocd/contrib"

if [ -f "$PREFIX/bin/openocd" ]; then
    mv -f "$PREFIX/bin/openocd" "$PREFIX/bin/openocd-macos-arm64-hid"
fi

echo
echo "built: $PREFIX/bin/openocd-macos-arm64-hid"
"$PREFIX/bin/openocd-macos-arm64-hid" --version | head -1
