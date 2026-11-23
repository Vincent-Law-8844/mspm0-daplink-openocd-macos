# Upstream report draft: MSPM0 flash programming is CMSIS-DAP HID latency bound

## Summary

Programming a 54,720-byte MSPM0L1117 image with a HID CMSIS-DAP probe takes
**110.9 s** (0.49 KiB/s) with TI OpenOCD 0.12.0+dev. The SWD clock makes no
difference: 2, 4, 8 and 12 MHz all take the same time. Almost all of the time is
the per-8-byte-word flash programming loop, where each command register write
is a separate USB HID transfer.

A local patch that batches the command-register writes into one DAP transfer
reduces this to **21.8 s** (2.45 KiB/s), a 5.1× improvement. It is still bounded
by at least one HID transfer per flash word.

## Environment

- OpenOCD: `0.12.0+dev`, TI `ti-openocd` commit `47bf607`
- Probe: MuseLab CMSIS-DAP, FW 2.1.0, HID interface (VID:PID `0d28:0204`)
- Target: MSPM0L1117, 128 KB flash / 16 KB SRAM / 2 banks
- Host: macOS arm64
- Firmware: `a2l_infineon_project.out`
  - ELF size: 521,416 bytes (includes DWARF)
  - Loadable flash: 54,720 bytes
  - SHA-256: `62a805329df468592db5195b896d1676a9ed718724786856e7a2c0dbb349c05f`

## Reproduction

```bash
openocd \
  -s <openocd>/share/openocd/scripts \
  -f interface/cmsis-dap.cfg \
  -f target/ti_mspm0.cfg \
  -c "adapter serial 0700000100380045470000044e544634a5a5a5a597969908" \
  -c "adapter speed 2000" \
  -c "gdb_port disabled; tcl_port disabled; telnet_port disabled" \
  -c "program {a2l_infineon_project/Debug/a2l_infineon_project.out} verify reset exit"
```

Observed:

```text
** Programming Started **
** Programming Finished **
** Verify Started **
** Verified OK **
** Resetting Target **
shutdown command invoked
real 110.91
```

Erasing the 54 used sectors alone is `0.76 s`; write-only is `109.68 s`, so the
programming loop dominates. The same 456-byte test image takes ~1.33 s at
2/4/8/12 MHz, confirming the clock is not the limit.

## Why it is slow

The stock `mspm0_write()` does this for every 64-bit flash word:

1. write `CMDTYPE`
2. write `CMDBYTEN`
3. write `CMDADDR`
4. write the sector protect register
5. write `CMDDATA0`
6. write `CMDDATA1`
7. write `CMDEXEC`
8. poll `STATCMD`

Each `target_write_u32()` / `target_read_u32()` is its own CMSIS-DAP transfer.
On this HID probe a transfer costs about 2 ms, so one 8-byte word costs about
16 ms. 54,720 / 8 × 16 ms ≈ 110 s.

## Local patch

`patches/mspm0-batch-ap-writes.patch` against `47bf607`:

- queue the command writes into one `dap_run()` using
  `dap_queue_ap_write()` (batched AP writes, no per-register USB round-trip);
- combine the adjacent `CMDADDR`/`CMDBYTEN` and `CMDDATA0`/`CMDDATA1` writes;
- cache `CMDTYPE` after the first word;
- read `STATCMD` as the last transfer of the same batch, with a normal poll
  fallback if the flash command has not completed yet;
- cache the dual-bank `SYSCTL_SECSTATUS` bit during probe instead of reading it
  for every word.

Result: 21.82 s and 21.81 s on two runs, `Verified OK` both times.

The remaining cost is one ~2 ms command transfer per word plus an occasional
poll. Getting substantially below ~14 s for this image requires target-side
programming (a RAM flash algorithm) or a bulk CMSIS-DAP v2 probe; host-side
batching cannot remove the HID round-trip.

## Suggested upstream direction

1. Consider batching the command-register writes as in the patch (or a cleaner
   variant that uses the existing MEM-AP helpers).
2. Consider a target-side flash algorithm for MSPM0 so the host can send a
   block of bytes instead of one command per 8-byte word.
3. Document that `adapter speed` above 2 MHz does not improve MSPM0 flash
   programming with HID CMSIS-DAP.

## Important DAPLink UART warning

Do **not** keep the DAPLink CDC UART open while programming. On this setup it
can make the flash controller lose the AP; the chip then needs a mass erase
before it can be flashed again. Reproduction should keep the UART closed. This
looks like a DAPLink firmware/USB-composite interaction rather than an OpenOCD
protocol issue, but it is worth documenting for users of HID CMSIS-DAP probes.
