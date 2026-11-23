# NOTICE

This repository redistributes a prebuilt OpenOCD binary for macOS arm64.

- Upstream project: OpenOCD, <https://openocd.org/> (GPL-2.0-or-later)
- Source used: Texas Instruments `ti-openocd` fork,
  <https://github.com/TexasInstruments/ti-openocd>
- Exact commit: `47bf6076181862fe3d7509f4aa49c27dc10f7730`
- Local patch: `patches/mspm0-batch-ap-writes.patch` (MSPM0 AP-write batching)
- Build configuration (macOS arm64):

```text
./configure --prefix=<dist/openocd-macos-arm64-hid> \
  --enable-cmsis-dap --enable-cmsis-dap-v2 --enable-xds110 \
  --disable-jlink --disable-ftdi --disable-stlink \
  --disable-doxygen-html --disable-werror
```

This build uses TI's source plus one local patch,
`patches/mspm0-batch-ap-writes.patch`, to batch MSPM0 flash command writes.
Exact upstream source snapshots are in `source/`, and
`scripts/build-openocd-macos.sh` reproduces the build from upstream git and
applies the patch.

The MSPM0 target and flash support (`tcl/target/ti_mspm0.cfg`,
`src/flash/nor/mspm0.c`) come from the same TI fork and remain under GPLv2.

OpenOCD is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 2 of the License, or (at your option) any later
version. See [LICENSE](LICENSE).

This repository is not affiliated with or endorsed by Texas Instruments.
