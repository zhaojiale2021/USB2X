<div align="center">

# USB2X

基于 STM32F072 的 USB 转 CAN 适配器固件，兼容 PEAK PCAN-USB 协议。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MCU](https://img.shields.io/badge/MCU-STM32F072%20%7C%20Cortex--M0-blue.svg)](https://www.st.com/en/microcontrollers-microprocessors/stm32f072xb.html)
[![Protocol](https://img.shields.io/badge/protocol-PEAK%20PCAN--USB-informational.svg)](#-协议支持)
[![Build](https://img.shields.io/badge/build-CMake%20%7C%20xmake-brightgreen.svg)](#-构建矩阵)
[![CI](https://github.com/zhaojiale2021/USB2X/actions/workflows/build.yml/badge.svg)](https://github.com/zhaojiale2021/USB2X/actions/workflows/build.yml)

[English](../../README.md) | [🌍 中文](./README.md)

</div>

---

把它插上 USB，设备会枚举为 **XCAN-USB** 适配器（VID `0x0483`，PID `0x000C`）。
支持 PCAN-USB 线协议的 Host 软件可以通过 SJA1000 `BTR0`/`BTR1` 配置波特率、启停
CAN 总线，并通过两个批量端点收发经典 CAN 2.0A/B 帧。整个适配器是运行在 Cortex-M0
上的轮询超级循环 —— 没有 RTOS、没有堆、不依赖厂商 SDK，只使用 STM32 HAL 和 ST 的
USB Device Library。Release 构建约占 19 KB Flash 和 7.5 KB RAM，对于 STM32F072xB 的
128 KB / 16 KB 资源仍有充足余量。

> ⚠️ 设备使用 ST 的 VID/PID 枚举，而不是 PEAK 的。按 VID/PID 匹配的官方 PEAK 驱动
> 需要先把 `0483:000C` 加入设备表，才能绑定该设备。

## 🚀 30 秒上手

```bash
git clone --recursive https://github.com/zhaojiale2021/USB2X.git
cd USB2X

./build.sh release                  # CMake + Ninja，默认 CANABLE 变体
# → build/bin/Release/USB2X.elf（以及 USB2X.map）

# 使用 ST-LINK 烧录（STM32CubeProgrammer）
STM32_Programmer_CLI -c port=SWD -d build/bin/Release/USB2X.elf -rst
```

更习惯 xmake？源码和输出路径完全一致：

```bash
xmake f -m release --variant=CANABLE -y
xmake                               # → build/bin/Release/USB2X.elf
```

Release 构建的实际大小（CANABLE）：text 19,272 B + data 276 B —— 约 19 KB Flash、
7.2 KB BSS。

依赖：`arm-none-eabi-gcc`（Cortex-M0）、CMake ≥ 3.24 + Ninja，或 xmake。两套构建
系统按 `ARM_GCC_BIN`（包含 `arm-none-eabi-gcc` 的 bin 目录）→ STM32CubeIDE 1.15.0
默认路径 → `PATH` 的顺序查找工具链。克隆时没加 `--recursive`？执行
`git submodule update --init --recursive`。

## 🌟 你能得到什么

| 当你需要… | 它做了什么 |
| --- | --- |
| **PCAN-USB 命令通道** | 16 字节批量 CMD OUT/IN 端点，承载波特率、时钟、总线开关、设备 ID、序列号、SJA1000 寄存器、错误帧掩码和 LED 命令 |
| **CAN 帧流** | 64 字节批量 MSG OUT/IN 端点承载批量 PCAN 帧记录；支持 CAN 2.0A/B、标准/扩展 ID、RTR、DLC 0–8 |
| **兼容 PEAK 的时序** | TIM3 产生 42.666 µs 时基；每个 USB 块的第一条记录携带完整 16 位时间戳，之后为 8 位增量；每秒发送一次时间同步和错误记录 |
| **背压而不是盲目丢帧** | 100 帧软件 TX FIFO、USB NAK 流控、发送重试直到总线关闭或 1 秒超时 |
| **由 Host 配置波特率** | `BTR0`/`BTR1` 按 PCAN 的 8 MHz 时序公式精确映射到 bxCAN；支持只听（silent）模式 |
| **板型灵活** | 五种编译期变体；OLLIE 额外提供 5 V / 3.3 V / 1.8 V 电源轨的使能、LED 和检测引脚 |
| **两套构建系统** | CMake preset 与 xmake mode 使用相同的源码、编译选项和输出路径 |
| **裸机体积** | 轮询超级循环，无 RTOS、无堆，Release 约 19 KB Flash |

## 🔌 协议支持

一个接口，四个批量端点：

| 端点 | 地址 | 大小 | 用途 |
| --- | --- | --- | --- |
| CMD OUT | `0x01` | 16 B | Host 下发的命令 |
| CMD IN | `0x81` | 16 B | 命令响应 |
| MSG OUT | `0x02` | 64 B | Host 下发的 CAN 帧记录 |
| MSG IN | `0x82` | 64 B | 批量上报给 Host 的 CAN 记录 |

Host→设备 的帧记录由状态/长度字节（bit 5 扩展 ID、bit 4 RTR、低 4 位 DLC）、2 或 4
字节 CAN ID、数据负载和可选的回显字节组成。设备→Host 的记录额外带时间戳 —— 每个
64 字节块的第一帧为 16 位，后续帧为 8 位增量；每个块以 `0x02` 和记录数开头。

| PCAN 命令 | ID | 状态 |
| --- | --- | --- |
| `BITRATE` get/set | 1 | ✅ `BTR0`/`BTR1` 解码到 bxCAN 预分频/时序，并可读回 |
| `CLOCK` get | 2 | ✅ 返回 16 MHz |
| `BUS` on/off | 3 | ✅ 启停 bxCAN；启动时发送第一帧时间同步 |
| `DEVID` get/set | 4 | ✅ 默认 `0xFF` |
| `CFG` | 5 | ⚪ 接受但无操作 |
| `SN` get | 6 | ✅ 固定默认值 `0xFFFFFFFF` |
| `REGISTER` get/set | 9 | ✅ SJA1000 BasicCAN/PeliCAN 寄存器影子（模式、BTR、ACR/AMR、CDR） |
| `EXT_VCC` | 10 | ⚪ 仅保存状态，未连接到引脚 |
| `ERR_FR` 错误掩码 | 11 | ✅ 选择需要上报的错误标志 |
| `LED` get/set | 12 | ⚪ 仅保存数值；LED 跟随总线状态和收发活动 |
| `SETCAN2FLASH` | `0xC8` | ⚪ 忽略（不支持大容量存储/引导模式） |
| 静默模式 | `SET_SILENT_MODE`（EX3，功能号 3） | ✅ 将 bxCAN 切换为只听模式 |

SJA1000 模型是寄存器影子，而不是真实芯片的克隆：它让 PCAN 风格的驱动能够完成寄存器
级的初始化流程，而真正的硬件配置来自专门的波特率/总线命令。

## 🧩 板型变体

编译时通过 `-DVARIANT=<name>`（CMake）或 `--variant=<name>`（xmake）选择。

| 变体 | 板型 / 用途 | 引脚映射 |
| --- | --- | --- |
| `CANABLE`（默认） | 通用 CANable 风格 USB-CAN 适配器 | CAN RX/TX `PB8`/`PB9`，TX LED `PB1`，RX LED `PB0` |
| `ENTREE` | Entree | 与 CANABLE 相同 |
| `CANTACT_8` | CANtact 8 MHz 板 | 与 CANABLE 相同 |
| `CANTACT_16` | CANtact 16 MHz 板 | 与 CANABLE 相同 |
| `OLLIE` | 带可选电源轨的适配器 | CAN RX/TX `PB8`/`PB9`，电源轨使能 `PC13`–`PC15`，电源轨 LED `PA5`–`PA7`，电源轨检测 `PB4`–`PB6` |

所有变体都实现 [`include/pcan_variant.h`](../../include/pcan_variant.h) 中相同的
`pcan_variant_io_init()` 约定；新增一块板子只需要增加一个 preset 和一组引脚定义。
在 OLLIE 上，当对应的电压检测输入为低时，固件会打开该电源轨并使能对应 LED。

时钟树默认使用 16 MHz HSE（见
[`include/stm32f0xx_hal_conf.h`](../../include/stm32f0xx_hal_conf.h)）经 PLL 倍频到 48 MHz。
8 MHz 晶振请在编译定义中加上 `-DHSE_VALUE=8000000`（PLL ×6）；设为 `0` 则回退到
HSI48 并使用 USB CRS 校准。注意 `CANTACT_8`/`CANTACT_16` 目前只选择引脚映射，并不会
改变时钟配置。

## 🏗️ 工作原理

```
main() → HAL_Init → 时钟 → pcan_usb_init / led / timestamp / protocol
       → loop { pcan_usb_poll(); pcan_led_poll(); pcan_protocol_poll(); }
```

- `pcan_usb_poll()` 调用 `HAL_PCD_IRQHandler()`；端点回调把命令和帧记录交给协议层。
- `pcan_protocol_poll()` 产生 1 Hz 的时间同步/错误记录，把批量记录刷到 MSG IN，并
  驱动 CAN 轮询。
- `pcan_can_poll()` 调用 `HAL_CAN_IRQHandler()`，并带重试地排空 TX FIFO。

USB 和 CAN 的“中断”都是通过超级循环直接调用 HAL 处理函数来服务的；只有 SysTick
作为真正的中断运行，为 `HAL_GetTick()` 提供时基。

## 📁 仓库结构

```
include/                 驱动、协议和板级头文件
  pcan_packet.h          PCAN/USB 命令常量与 SJA1000 寄存器映射
  pcan_variant.h          按变体宏选择的板级引脚映射
src/c/                   应用源码
  main.c                 时钟配置与超级循环
  pcan_usb.c             USB 类：描述符、端点状态机、数据泵
  pcan_protocol.c        命令解析与 CAN 记录编解码
  pcan_can.c             bxCAN 驱动、TX FIFO、错误回调
  pcan_timestamp.c       TIM3 42.666 µs 滴答计数器
  pcan_led.c             LED 模式/闪烁状态机
src/startup/             向量表与 STM32F072xB 链接脚本
presets/                 各变体的 CMake 片段
xmake/                   xmake 工具链、选项与目标
toolchains/              arm-none-eabi CMake 工具链文件
lib/STM32CubeF0/         ST HAL + USB Device Library（git 子模块）
tools/clang_format/      格式化工具与 pre-commit 钩子
.github/workflows/       CI：CMake（debug/release）与 xmake（release）构建
```

## ⚙️ 构建矩阵

| CMake preset | xmake mode | 编译选项 | 输出 |
| --- | --- | --- | --- |
| `debug` | `debug` | `-g -Wall -Wextra` | `build/bin/Debug/USB2X.elf` |
| `release` | `release` | `-O2 -Wall -Wextra` | `build/bin/Release/USB2X.elf` |
| `reldebug` | `releasedbg` | `-O2 -g -Wall -Wextra` | `build/bin/RelWithDebInfo/USB2X.elf` |
| `minsize` | `minsizerel` | `-Os -Wall -Wextra` | `build/bin/MinSizeRel/USB2X.elf` |

```bash
./build.sh                          # debug 配置 + 构建
./build.sh release                  # release 配置 + 构建
./build.sh debug all OLLIE          # OLLIE 变体的 debug 构建
./build.sh clean                    # 删除 build/

xmake f -m debug --variant=OLLIE -y # 等价的 xmake 用法
xmake
```

代码格式化使用 clang-format（Google 风格，120 列）；可执行文件位于
`tools/clang_format/clang_format.exe`，并已接入 pre-commit 钩子。

## ⚠️ 状态与限制

- **驱动 VID/PID**：官方 PEAK 驱动匹配 `0C72:000C`；需要先把 `0483:000C` 加入驱动
  的设备表（或使用按 ID 打开设备的 Host 软件）。
- **单通道**：只有一个 CAN 控制器，不支持 CAN FD、不含 ISO-TP —— ISO-TP、CANopen
  等协议层应由 Host 实现。
- **寄存器模型**：SJA1000 读取返回影子值；不上报 CAN 错误计数器；验收滤波为全接收
  （32 位掩码滤波器）。
- **占位实现**：`CFG`、`EXT_VCC`、`LED` 模式和 `SETCAN2FLASH` 会被接受，但不会
  改变硬件；CAN 驱动里有回环模式，但未通过 USB 暴露。
- **时间戳**：16 位 42.666 µs 滴答约每 2.8 秒回绕；每秒一次的时间同步记录让 Host
  软件能够重建绝对时间。

## 🤝 贡献

欢迎 issue 和 pull request。提交 PR 前请确保 `debug` 构建无警告，并用 clang-format
格式化 C 源码。CI 会构建 debug/release 两个 CMake preset 以及 xmake release 配置。
目前还没有自动化测试套件 —— 在真实适配器上的硬件在环测试是最终参考。

## 📄 许可证

MIT，详见 [LICENSE](../../LICENSE)。

PCAN-USB 是 PEAK-System Technik GmbH 的商标。本项目与 PEAK-System 无隶属关系，
也未获得其认可。

---

<div align="center">

**线缆上是 PCAN-USB，板子上是几 KB 的 Cortex-M0。**

[⭐ 在 GitHub 上 Star](https://github.com/zhaojiale2021/USB2X) · [🐛 反馈问题](https://github.com/zhaojiale2021/USB2X/issues)

</div>
