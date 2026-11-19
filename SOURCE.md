# Source

The prebuilt binary in `dist/` is GPLv2 OpenOCD. Exact source snapshots used for
this build are included here:

- `source/ti-openocd-47bf607.tar.gz` — Texas Instruments `ti-openocd` at commit
  `47bf6076181862fe3d7509f4aa49c27dc10f7730`
- `source/jimtcl-1933e545.tar.gz` — the `jimtcl` submodule at commit
  `1933e5457b9512d39ebbe11ed32578aada149f49`

The build script `scripts/build-openocd-macos.sh` clones the upstream git
repositories at the same commits. To build from the tarballs instead, extract
them so the tree looks like:

```text
ti-openocd/
├── jimtcl/                 # extracted from jimtcl-1933e545.tar.gz
└── ...                     # extracted from ti-openocd-47bf607.tar.gz
```

No source files were modified for this build; only the `configure` options
differ from TI's published macOS build (CMSIS-DAP HID support via `hidapi`).
