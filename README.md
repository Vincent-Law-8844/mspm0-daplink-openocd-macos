# mspm0-daplink-openocd-macos

Unofficial prebuilt TI OpenOCD for macOS arm64 with CMSIS-DAP **HID** support —
flash and debug **MSPM0L1117** over a **DAPLink (CMSIS-DAP)** probe, including
VS Code + Cortex-Debug.

[English](#english) | [中文](#中文)

---

## English

### What this is

A small, self-contained macOS arm64 package for the **MSPM0L1117 + DAPLink**
combination:

- Prebuilt TI OpenOCD (`0.12.0+dev`, TI `ti-openocd` commit `47bf607`)
- `scripts/flash.sh` — one-command flash
- `.vscode/launch.json` + `.vscode/tasks.json` — Cortex-Debug and a flash task
- `examples/gpio_toggle.out` — test image for verifying flash/run
- Exact GPL source snapshots in `source/`

Not affiliated with or endorsed by Texas Instruments.

### Why this build exists

TI's official macOS OpenOCD packages (1.5.2 and 1.3.1.50) link **libusb only**.
Common DAPLink probes such as MuseLab CMSIS-DAP are **HID** devices, so the
official build fails with:

```text
Error: unable to find a matching CMSIS-DAP device
```

This build enables **CMSIS-DAP HID** via `hidapi`, so those probes work.

### Verified

| Item | Result |
|---|---|
| Host | macOS / Apple Silicon (arm64) |
| Probe | MuseLab CMSIS-DAP, `0d28:0204`, HID interface |
| Target | MSPM0L1117, 128 KB flash / 16 KB SRAM / 2 banks |
| Flash | `program ... verify reset exit` → `Verified OK` |
| Debug | GDB `load` + `break main` → stops at `main` |

The target ID is `0x0BBB402F`. OpenOCD 1.5.2 does not yet list this exact part,
so it logs:

```text
Unidentified PART[0xaf6c]/variant[0xb0], unknown DeviceID[0xbbb4]. Attempting to proceed as mspm0x.
```

This is cosmetic: the driver reads `SRAMFLASH` and auto-configures 128 KB /
16 KB / 2 banks. Flashing and verification work. See
[`docs/VERIFICATION.md`](docs/VERIFICATION.md) for logs.

### Performance

Measured with a real 54,720-byte image on this MSPM0L1117 + MuseLab DAPLink:

| Build | Flash + verify | Rate |
|---|---|---|
| Stock TI build | 110.9 s | 0.49 KiB/s |
| Batched AP-write patch | 21.8 s | 2.45 KiB/s |

`adapter speed` 2/4/8/12 MHz made no difference; the bottleneck is the HID USB
round-trip, not the SWD clock. The patch is
[`patches/mspm0-batch-ap-writes.patch`](patches/mspm0-batch-ap-writes.patch);
details and the remaining limit are in
[`docs/PERFORMANCE.md`](docs/PERFORMANCE.md). The ready-to-send upstream issue
draft is [`docs/UPSTREAM-REPORT.md`](docs/UPSTREAM-REPORT.md). The patch is
tested on MSPM0L1117; review it before using it on other MSPM0 parts.

### Layout

```text
.
├── dist/openocd-macos-arm64-hid/
│   ├── bin/openocd-macos-arm64-hid
│   └── share/openocd/scripts/
├── patches/mspm0-batch-ap-writes.patch
├── scripts/
│   ├── flash.sh
│   └── build-openocd-macos.sh
├── .vscode/
│   ├── launch.json
│   └── tasks.json
├── examples/
│   ├── gpio_toggle.out
│   └── gpio_toggle/
├── source/
│   ├── ti-openocd-47bf607.tar.gz
│   └── jimtcl-1933e545.tar.gz
├── docs/VERIFICATION.md
├── docs/PERFORMANCE.md
├── docs/UPSTREAM-REPORT.md
├── README.md
├── SOURCE.md
├── LICENSE
└── NOTICE.md
```

`build/`, `src/` and `private/` are ignored by Git. `private/` contains the
original 128 KB flash backup from the test board and is never uploaded.

### Requirements

```bash
brew install libftdi libusb hidapi capstone
```

Also:

- `arm-none-eabi-gdb` (Arm GNU Toolchain) for debugging
- VS Code + [Cortex-Debug](https://marketplace.visualstudio.com/items?itemName=marus25.cortex-debug)
  (only needed for the VS Code debug flow)

### Flash

```bash
./scripts/flash.sh                                  # test image
./scripts/flash.sh /path/to/your_project/Debug/your_project.out
```

Equivalent command:

```bash
OPENOCD_SCRIPTS="$PWD/dist/openocd-macos-arm64-hid/share/openocd/scripts" \
dist/openocd-macos-arm64-hid/bin/openocd-macos-arm64-hid \
  -f interface/cmsis-dap.cfg \
  -f target/ti_mspm0.cfg \
  -c "adapter speed 2000" \
  -c "program /path/to/your_project.out verify reset exit"
```

### VS Code debug

1. Install Cortex-Debug.
2. Edit `executable` in `.vscode/launch.json` to point at your `.out`.
3. Press F5.

The launch configuration starts OpenOCD, loads the ELF over GDB, and stops at
`main`. The “Flash MSPM0L1117” task (`Ctrl+Shift+B`) only flashes, without a
debug session.

### Rebuild

```bash
brew install autoconf automake libtool pkg-config
./scripts/build-openocd-macos.sh
```

The script clones TI `ti-openocd` at `47bf607` and builds with
`--enable-cmsis-dap` and `hidapi` into `dist/openocd-macos-arm64-hid/`.

### Notes

- The binary is tied to the repo path through its compiled-in script prefix. The
  scripts and VS Code config set `OPENOCD_SCRIPTS` explicitly, so they keep
  working if the repo is moved or cloned elsewhere. For direct invocation, set
  `OPENOCD_SCRIPTS` or pass `-s`.
- Only one OpenOCD can own the DAPLink at a time, and both OpenOCD instances
  default to GDB port `3333`.
- **Do not keep the DAPLink CDC UART open while flashing.** It can make the
  MSPM0 lose the debug AP and require a mass erase. `scripts/flash.sh` refuses
  to run if a `/dev/cu.usbmodem*` port is already open.
- With TI clang ≤ 4.0.3, if breakpoints do not bind, run:
  `tiarmobjcopy --set-section-type=.TI.phattrs=1 your.out`.
  The 4.0.2 build used here works without it.
- `examples/gpio_toggle.out` is for flash/run verification only; its LED pins
  follow the LP-MSPM0L1117 example. Custom boards may not have the same LEDs.

### License

GPL-2.0-or-later. See [`LICENSE`](LICENSE), [`NOTICE.md`](NOTICE.md), and
[`SOURCE.md`](SOURCE.md).

---

## 中文

### 这是什么

一个面向 **MSPM0L1117 + DAPLink** 的 macOS arm64 自包含包：

- 预编译 TI OpenOCD（`0.12.0+dev`，TI `ti-openocd` commit `47bf607`）
- `scripts/flash.sh`：一条命令烧录
- `.vscode/launch.json` + `.vscode/tasks.json`：Cortex-Debug 调试和烧录任务
- `examples/gpio_toggle.out`：用于验证烧录/运行的测试固件
- `source/`：GPL 合规所需的精确源码快照

非 TI 官方发布，与 TI 无隶属关系。

### 为什么需要重新编译

TI 官方 macOS 版 OpenOCD（1.5.2 / 1.3.1.50）只链接了 `libusb`。常见的
DAPLink（例如 MuseLab CMSIS-DAP）是 **HID** 设备，所以官方包会报：

```text
Error: unable to find a matching CMSIS-DAP device
```

本仓库的版本通过 `hidapi` 启用了 **CMSIS-DAP HID**，因此可以连接这类探针。

### 已验证

| 项目 | 结果 |
|---|---|
| 主机 | macOS / Apple Silicon (arm64) |
| 调试器 | MuseLab CMSIS-DAP，`0d28:0204`，HID 接口 |
| 目标 | MSPM0L1117，128 KB Flash / 16 KB SRAM / 2 bank |
| 烧录 | `program ... verify reset exit` → `Verified OK` |
| 调试 | GDB `load` + `break main` → 停在 `main` |

目标 ID 为 `0x0BBB402F`。OpenOCD 1.5.2 还没有收录这个具体型号，所以会打印：

```text
Unidentified PART[0xaf6c]/variant[0xb0], unknown DeviceID[0xbbb4]. Attempting to proceed as mspm0x.
```

这只是名称识别没跟上，不影响烧录：驱动会读 `SRAMFLASH`，自动配置
128 KB / 16 KB / 2 bank。实测日志见 [`docs/VERIFICATION.md`](docs/VERIFICATION.md)。

### 烧录速度

用 54,720 字节的真实固件实测（MSPM0L1117 + MuseLab DAPLink）：

| 版本 | 烧录 + 校验 | 速度 |
|---|---|---|
| TI 原版 | 110.9 s | 0.49 KiB/s |
| 批量 AP 写补丁 | 21.8 s | 2.45 KiB/s |

`adapter speed` 2/4/8/12 MHz 对时间没有影响，瓶颈是 HID USB 往返延迟，不是 SWD
时钟。补丁在
[`patches/mspm0-batch-ap-writes.patch`](patches/mspm0-batch-ap-writes.patch)，
详细分析和剩余上限见 [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md)，可直接发给
OpenOCD 作者的 issue 草稿见 [`docs/UPSTREAM-REPORT.md`](docs/UPSTREAM-REPORT.md)。
补丁只在 MSPM0L1117 上验证过，其他型号使用前请先 review。

### 目录

```text
.
├── dist/openocd-macos-arm64-hid/
│   ├── bin/openocd-macos-arm64-hid
│   └── share/openocd/scripts/
├── patches/mspm0-batch-ap-writes.patch
├── scripts/
│   ├── flash.sh
│   └── build-openocd-macos.sh
├── .vscode/
│   ├── launch.json
│   └── tasks.json
├── examples/
│   ├── gpio_toggle.out
│   └── gpio_toggle/
├── source/
│   ├── ti-openocd-47bf607.tar.gz
│   └── jimtcl-1933e545.tar.gz
├── docs/VERIFICATION.md
├── docs/PERFORMANCE.md
├── docs/UPSTREAM-REPORT.md
├── README.md
├── SOURCE.md
├── LICENSE
└── NOTICE.md
```

`build/`、`src/`、`private/` 都被 `.gitignore` 忽略。`private/` 里是测试板的
原始 128 KB flash 备份，不会上传。

### 依赖

```bash
brew install libftdi libusb hidapi capstone
```

调试还需要：

- `arm-none-eabi-gdb`（Arm GNU Toolchain）
- VS Code + [Cortex-Debug](https://marketplace.visualstudio.com/items?itemName=marus25.cortex-debug)

### 烧录

```bash
./scripts/flash.sh                                  # 测试固件
./scripts/flash.sh /path/to/your_project/Debug/your_project.out
```

等价命令：

```bash
OPENOCD_SCRIPTS="$PWD/dist/openocd-macos-arm64-hid/share/openocd/scripts" \
dist/openocd-macos-arm64-hid/bin/openocd-macos-arm64-hid \
  -f interface/cmsis-dap.cfg \
  -f target/ti_mspm0.cfg \
  -c "adapter speed 2000" \
  -c "program /path/to/your_project.out verify reset exit"
```

### VS Code 调试

1. 安装 Cortex-Debug。
2. 修改 `.vscode/launch.json` 里的 `executable`，指向你的 `.out`。
3. 按 F5。

调试配置会启动 OpenOCD、通过 GDB `load` 烧录，并停在 `main`。
“Flash MSPM0L1117” 任务（`Ctrl+Shift+B`）只烧录，不进入调试。

### 重建

```bash
brew install autoconf automake libtool pkg-config
./scripts/build-openocd-macos.sh
```

脚本会拉取 TI `ti-openocd` 的 `47bf607`，用 `--enable-cmsis-dap` 和
`hidapi` 编译到 `dist/openocd-macos-arm64-hid/`。

### 注意

- 二进制内部有编译时的脚本路径；脚本和 VS Code 配置都显式设置了
  `OPENOCD_SCRIPTS`，所以仓库换目录也能用。直接调用二进制时要自己设
  `OPENOCD_SCRIPTS` 或加 `-s`。
- 同一个 DAPLink 同时只能被一个 OpenOCD 占用，两个 OpenOCD 也都默认使用
  GDB 端口 `3333`。
- **烧录时不要同时打开 DAPLink 的 UART 串口。** 否则可能导致 MSPM0 掉 AP，
  只能 mass erase 恢复。`scripts/flash.sh` 检测到 `/dev/cu.usbmodem*` 被占用时
  会直接拒绝烧录。
- 如果使用 TI clang ≤ 4.0.3，断点不生效时可以给 `.out` 补一步：
  `tiarmobjcopy --set-section-type=.TI.phattrs=1 your.out`。
  这里用的 4.0.2 实测不需要。
- `examples/gpio_toggle.out` 只用于验证烧录/运行，LED 引脚按
  LP-MSPM0L1117 示例配置；自定义板不一定有对应 LED。

### 许可证

GPL-2.0-or-later。见 [`LICENSE`](LICENSE)、[`NOTICE.md`](NOTICE.md)、
[`SOURCE.md`](SOURCE.md)。
