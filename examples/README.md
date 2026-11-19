# examples

`gpio_toggle.out` 是一个用于验证烧录/运行的测试固件，来自 MSPM0 SDK 2.11：

- 示例：`examples/nortos/LP_MSPM0L1117/driverlib/gpio_toggle_output`
- 编译器：TI Arm Clang 4.0.2.LTS
- SysConfig：1.26.2
- 目标：MSPM0L1117（128 KB Flash / 16 KB SRAM）

`gpio_toggle/` 保留了生成该 `.out` 所需的源文件和 SysConfig 生成文件；构建产物 `.o` / `.map` 没有放进来。

这个示例会翻转 LP-MSPM0L1117 示例里的 LED 引脚（PB16/PB17/PB18/PB14）。如果是自定义板，LED 不一定对应；它只用于确认“能烧进去并运行”。

烧录：

```bash
./scripts/flash.sh examples/gpio_toggle.out
```
