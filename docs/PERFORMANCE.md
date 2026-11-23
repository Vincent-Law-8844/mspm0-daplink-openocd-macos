# Flash performance

Measured with the real A2L firmware on a MuseLab CMSIS-DAP (HID) probe and an
MSPM0L1117. Only the loadable flash content counts; the `.out` is much larger
because it contains DWARF debug data.

| Item | Value |
|---|---|
| ELF file | `a2l_infineon_project.out`, 521,416 bytes |
| Loadable flash | 54,720 bytes (`.intvecs`, `.text`, `.rodata`, `.TI.ramfunc`, `.cinit`, `.binit`) |
| Probe | MuseLab CMSIS-DAP, FW 2.1.0, HID interface |
| Target | MSPM0L1117, 128 KB flash / 16 KB SRAM / 2 banks |
| OpenOCD | 0.12.0+dev, TI `ti-openocd` `47bf607` |

## Results

| Build | `program ... verify reset exit` | Rate |
|---|---|---|
| Stock TI OpenOCD | 110.91 s | 0.49 KiB/s |
| Batched AP-write patch | 21.82 s | 2.45 KiB/s |
| Batched patch, second run | 21.81 s | 2.45 KiB/s |
| Batched patch, GDB `load` (Cortex-Debug path) | 22.27 s | ~2 KB/s (GDB reported) |

Erase of the 54 used sectors is only ~0.76 s and verify is sub-second; almost
all of the time is the 8-byte flash-word programming loop.

## Adapter speed is not the bottleneck

With a 456-byte test image, the stock build took essentially the same time at
every SWD clock:

| `adapter speed` | Time |
|---|---|
| 2000 kHz | 1.33 s |
| 4000 kHz | 1.33 s |
| 8000 kHz | 1.32 s |
| 12000 kHz | 1.32 s |

The limit is the USB HID round-trip latency per CMSIS-DAP transfer, not SWD
clock rate.

## Root cause

The MSPM0 flash controller programs one 64-bit word per command. The stock
driver performed each command register write as a separate OpenOCD target
write, and therefore a separate CMSIS-DAP transfer:

- `CMDTYPE`
- `CMDBYTEN`
- `CMDADDR`
- protect register
- `CMDDATA0`
- `CMDDATA1`
- `CMDEXEC`
- poll `STATCMD`

That is about eight USB HID transfers per 8 bytes. At ~2 ms per HID transfer,
one word costs ~16 ms, and 54,720 bytes / 8 bytes × 16 ms ≈ 110 s.

## Patch

`patches/mspm0-batch-ap-writes.patch`:

- queues the command-register writes into one `dap_run()` (batched AP writes);
- combines the adjacent `CMDADDR`/`CMDBYTEN` and `CMDDATA0`/`CMDDATA1` writes;
- caches `CMDTYPE` after the first word;
- reads `STATCMD` as the last transfer of the same batch, and only performs an
  extra poll if the command has not completed.

This reduces the loop to roughly one command transfer plus an occasional poll,
for a 5.1× improvement.

## Remaining limit

21.8 s is still slow. With a HID CMSIS-DAP probe, each word still needs at least
one ~2 ms USB transfer, so OpenOCD's host-driven flash loop cannot go much below
~14 s for this image. Going substantially faster requires one of:

- a CMSIS-DAP v2 bulk probe (not the HID interface used here);
- a target-side flash algorithm that receives a block of data and programs it
  locally;
- a different probe/tool with a faster flash backend.

`adapter speed 12000` does not help.
