# 实测记录

日期：2026-11-19  
主机：macOS / Apple Silicon (arm64)  
探针：MuseLab CMSIS-DAP，USB `0d28:0204`，HID 接口  
目标：MSPM0L1117，128 KB Flash / 16 KB SRAM / 2 bank

## 1. 官方 macOS 包

TI 官方 `openocd_mac_1.5.2.82.zip` 和 `openocd_mac_1.3.1.50.zip` 都只链接了 `libusb`：

```text
$ otool -L openocd | grep -i -E 'hid|usb'
/opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib
```

连接 HID 版 DAPLink 时报错：

```text
Debug: 95 5 cmsis_dap.c:287 cmsis_dap_open(): unable to find a matching CMSIS-DAP device
Error: 96 5 command.c:529 exec_command(): Command 'init' failed with error code -4
```

## 2. 重编后连接与识别

构建：TI `ti-openocd` commit `47bf607`，启用 `hidapi` 和 `--enable-cmsis-dap`。

```text
Info : CMSIS-DAP: SWD supported
Info : CMSIS-DAP: FW Version = 2.1.0
Info : CMSIS-DAP: Interface Initialised (SWD)
Info : SWD DPIDR 0x6ba02477
Info : [mspm0x.cpu] Cortex-M0+ r0p1 processor detected
Info : Unidentified PART[0xaf6c]/variant[0xb0], unknown DeviceID[0xbbb4]. Attempting to proceed as mspm0x.
flash 'mspm0' found at 0x00000000
#0 : mspm0x.flash.main (mspm0) at 0x00000000, size 0x00020000
```

工厂寄存器：

```text
DID         = 0x0BBB402F
SRAMFLASH   = 0x00101080   # 128 KB main flash, 16 KB SRAM, 2 banks
```

## 3. 烧录

```text
** Programming Started **
** Programming Finished **
** Verify Started **
** Verified OK **
** Resetting Target **
```

## 4. GDB 调试（Cortex-Debug 的路径）

```text
Loading section .intvecs, size 0xc0 lma 0x0
Loading section .text, size 0x108 lma 0xc0
Start address 0x00000158, load size 456
Breakpoint 1, main () at gpio_toggle_output.c:41
pc             0xc8                0xc8 <main+8>
```

结论：`program` 和 GDB `load` 两条路径都可用；Cortex-Debug F5 会走 GDB `load`。

## 5. 备份

测试前已把主 flash 的 128 KB 原始内容备份为 `private/backup_flash.bin`（被 `.gitignore` 忽略，不随仓库上传）。
