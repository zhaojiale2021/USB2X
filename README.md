<div align="center">

# USB2X

STM32F072 USB-to-CAN adapter firmware that speaks the PEAK PCAN-USB protocol.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MCU](https://img.shields.io/badge/MCU-STM32F072%20%7C%20Cortex--M0-blue.svg)](https://www.st.com/en/microcontrollers-microprocessors/stm32f072xb.html)
[![Protocol](https://img.shields.io/badge/protocol-PEAK%20PCAN--USB-informational.svg)](#-protocol-support)
[![Build](https://img.shields.io/badge/build-CMake%20%7C%20xmake-brightgreen.svg)](#-build-matrix)
[![CI](https://github.com/zhaojiale2021/USB2X/actions/workflows/build.yml/badge.svg)](https://github.com/zhaojiale2021/USB2X/actions/workflows/build.yml)

[English](./README.md) | [🌍 中文](./docs/zh-CN/README.md)

</div>

---

Plug the board into USB and it enumerates as an **XCAN-USB** adapter (VID `0x0483`,
PID `0x000C`). Host software that speaks the PCAN-USB wire protocol can configure the
bitrate from SJA1000 `BTR0`/`BTR1` values, start and stop the bus, and exchange classic
CAN 2.0A/B frames over two bulk endpoints. The whole adapter is a polled super-loop on a
Cortex-M0 — no RTOS, no heap, no vendor SDK: just the STM32 HAL and ST's USB Device
Library. A release build is roughly 19 KB of flash and 7.5 KB of RAM, leaving plenty of the
128 KB / 16 KB on an STM32F072xB.

> ⚠️ The adapter enumerates with ST's VID/PID, not PEAK's. Stock PEAK drivers that match
> on VID/PID need `0483:000C` added to their device table before they bind to it.

## 🚀 30-second start

```bash
git clone --recursive https://github.com/zhaojiale2021/USB2X.git
cd USB2X

./build.sh release                  # CMake + Ninja, CANABLE variant
# → build/bin/Release/USB2X.elf (+ USB2X.map)

# Flash with an ST-LINK (STM32CubeProgrammer)
STM32_Programmer_CLI -c port=SWD -d build/bin/Release/USB2X.elf -rst
```

Prefer xmake? It builds the same sources to the same paths:

```bash
xmake f -m release --variant=CANABLE -y
xmake                               # → build/bin/Release/USB2X.elf
```

Expected release size (CANABLE): 19,272 B text + 276 B data — about 19 KB of flash and
7.2 KB of BSS.

Requirements: `arm-none-eabi-gcc` (Cortex-M0). CMake ≥ 3.24 with Ninja, or xmake. Both
build systems resolve the toolchain from `ARM_GCC_BIN` (the bin directory containing
`arm-none-eabi-gcc`), then the STM32CubeIDE 1.15.0 path, then `PATH`. Cloned without
`--recursive`? Run `git submodule update --init --recursive`.

## 🌟 What you get

| When you need… | What it does |
| --- | --- |
| **PCAN-USB command channel** | 16-byte bulk CMD OUT/IN endpoints carrying bitrate, clock, bus on/off, device ID, serial, SJA1000 register, error-frame mask and LED commands |
| **CAN frame streaming** | 64-byte bulk MSG OUT/IN endpoints carrying batched PCAN frame records; CAN 2.0A/B, standard/extended IDs, RTR, DLC 0–8 |
| **PEAK-compatible timing** | 42.666 µs ticks from TIM3; full 16-bit timestamp on the first record of each USB block, 8-bit deltas afterwards; 1 Hz time-sync and error records |
| **Back-pressure instead of blind drops** | 100-frame software TX FIFO, USB NAK flow control, TX retry until bus-off or a 1 s timeout |
| **Bitrate from the host** | `BTR0`/`BTR1` mapped so the PCAN 8 MHz timing equation is reproduced exactly on bxCAN; listen-only (silent) mode supported |
| **Board flexibility** | Five compile-time variants; OLLIE adds 5 V / 3.3 V / 1.8 V rails with enable, LED and sense pins |
| **Two build systems** | CMake presets and xmake modes with identical sources, flags and output paths |
| **Bare-metal footprint** | Polled super-loop, no RTOS, no heap, ~19 KB flash in release |

## 🌐 USB-Ethernet demo (STM32F746G-DISCO)

This repository also contains a separate **100 Mbps USB-Ethernet demo**:
TinyUSB CDC-NCM bridged to the on-board LAN8742A PHY, with no TCP/IP stack on
the MCU. It targets the STM32F746G-DISCO (USB HS ULPI + RMII PHY) and does not
use the PCAN firmware. See [examples/usb_eth_f7](examples/usb_eth_f7/).

## 🔌 Protocol support

One interface, four bulk endpoints:

| Endpoint | Address | Size | Purpose |
| --- | --- | --- | --- |
| CMD OUT | `0x01` | 16 B | Commands from host |
| CMD IN | `0x81` | 16 B | Command responses |
| MSG OUT | `0x02` | 64 B | CAN frame records from host |
| MSG IN | `0x82` | 64 B | Batched CAN records to host |

A host→device frame record is a status/length byte (bit 5 extended ID, bit 4 RTR, low
nibble DLC), a 2- or 4-byte CAN ID, the payload, and an optional echo byte. Device→host
records add a timestamp — 16 bits on the first frame of each 64-byte block, 8-bit deltas
afterwards — and each block starts with `0x02` plus a record count.

| PCAN command | ID | Status |
| --- | --- | --- |
| `BITRATE` get/set | 1 | ✅ `BTR0`/`BTR1` decoded onto bxCAN prescaler/timing and readable back |
| `CLOCK` get | 2 | ✅ reports 16 MHz |
| `BUS` on/off | 3 | ✅ starts/stops bxCAN; emits the first time-sync on start |
| `DEVID` get/set | 4 | ✅ defaults to `0xFF` |
| `CFG` | 5 | ⚪ accepted, no-op |
| `SN` get | 6 | ✅ fixed default `0xFFFFFFFF` |
| `REGISTER` get/set | 9 | ✅ SJA1000 BasicCAN/PeliCAN register shadow (mode, BTR, ACR/AMR, CDR) |
| `EXT_VCC` | 10 | ⚪ state stored, not wired to a pin |
| `ERR_FR` error mask | 11 | ✅ selects which error flags are reported |
| `LED` get/set | 12 | ⚪ value stored; LEDs follow bus state and traffic |
| `SETCAN2FLASH` | `0xC8` | ⚪ ignored (no mass-storage / bootloader mode) |
| Silent mode | `SET_SILENT_MODE` (EX3, function 3) | ✅ switches bxCAN to listen-only |

The SJA1000 model is a register shadow, not a silicon clone: it lets a PCAN-style driver
complete its register-level init sequence, while actual hardware configuration comes from
the dedicated bitrate/bus commands.

## 🧩 Board variants

Selected at compile time with `-DVARIANT=<name>` (CMake) or `--variant=<name>` (xmake).

| Variant | Board / purpose | Pin map |
| --- | --- | --- |
| `CANABLE` (default) | Generic CANable-style USB-CAN adapter | CAN RX/TX `PB8`/`PB9`, TX LED `PB1`, RX LED `PB0` |
| `ENTREE` | Entree | Same as CANABLE |
| `CANTACT_8` | CANtact 8 MHz board | Same as CANABLE |
| `CANTACT_16` | CANtact 16 MHz board | Same as CANABLE |
| `OLLIE` | Adapter with selectable supply rails | CAN RX/TX `PB8`/`PB9`, rail enables `PC13`–`PC15`, rail LEDs `PA5`–`PA7`, rail sense `PB4`–`PB6` |

Every variant implements the same `pcan_variant_io_init()` contract in
[`include/pcan_variant.h`](include/pcan_variant.h); adding a board means adding a preset and
a pin block. On OLLIE each rail is enabled and its LED lit when the matching
voltage-sense input reads low.

The clock tree uses a 16 MHz HSE (`HSE_VALUE` in
[`include/stm32f0xx_hal_conf.h`](include/stm32f0xx_hal_conf.h)) PLL-multiplied to 48 MHz.
For an 8 MHz crystal add `-DHSE_VALUE=8000000` to the compile definitions (PLL ×6); set it
to `0` to fall back to HSI48 with USB CRS trimming. Note that `CANTACT_8`/`CANTACT_16`
currently select the pin map only — they do not change the clock configuration.

## 🏗️ How it works

```
main() → HAL_Init → clock → pcan_usb_init / led / timestamp / protocol
       → loop { pcan_usb_poll(); pcan_led_poll(); pcan_protocol_poll(); }
```

- `pcan_usb_poll()` calls `HAL_PCD_IRQHandler()`; endpoint callbacks hand commands and
  frame records to the protocol layer.
- `pcan_protocol_poll()` emits the 1 Hz time-sync/error records, flushes batched records
  to MSG IN, and drives the CAN polling.
- `pcan_can_poll()` calls `HAL_CAN_IRQHandler()` and drains the TX FIFO with retries.

USB and CAN interrupts are serviced by calling their HAL handlers from the super-loop;
only SysTick runs as a real interrupt, feeding `HAL_GetTick()`.

## 📁 Repository layout

```
include/                 Driver, protocol and board headers
  pcan_packet.h          PCAN/USB command constants and SJA1000 register map
  pcan_variant.h          Per-board pin maps, selected by variant macro
src/c/                   Application sources
  main.c                 Clock setup and super-loop
  pcan_usb.c             USB class: descriptors, endpoint FSM, data pump
  pcan_protocol.c        Command decoding and CAN record marshalling
  pcan_can.c             bxCAN driver, TX FIFO, error callbacks
  pcan_timestamp.c       TIM3 42.666 µs tick counter
  pcan_led.c             LED mode/blink state machine
src/startup/             Vector table and STM32F072xB linker script
presets/                 Per-variant CMake fragments
xmake/                   xmake toolchain, options and target
toolchains/              arm-none-eabi CMake toolchain file
lib/STM32CubeF0/         ST HAL + USB Device Library (git submodule)
lib/tinyusb/             TinyUSB (git submodule, used by the F7 demo)
examples/usb_eth_f7/     STM32F746G-DISCO USB-Ethernet demo (TinyUSB NCM)
tools/clang_format/      Formatter binary and pre-commit hook
.github/workflows/       CI: F072 builds and the F7 USB-Ethernet demo
```

## ⚙️ Build matrix

| CMake preset | xmake mode | Flags | Output |
| --- | --- | --- | --- |
| `debug` | `debug` | `-g -Wall -Wextra` | `build/bin/Debug/USB2X.elf` |
| `release` | `release` | `-O2 -Wall -Wextra` | `build/bin/Release/USB2X.elf` |
| `reldebug` | `releasedbg` | `-O2 -g -Wall -Wextra` | `build/bin/RelWithDebInfo/USB2X.elf` |
| `minsize` | `minsizerel` | `-Os -Wall -Wextra` | `build/bin/MinSizeRel/USB2X.elf` |

```bash
./build.sh                          # debug configure + build
./build.sh release                  # release configure + build
./build.sh debug all OLLIE          # debug build for the OLLIE variant
./build.sh clean                    # remove build/

xmake f -m debug --variant=OLLIE -y # xmake equivalent
xmake
```

Formatting uses clang-format (Google style, 120 columns); the binary lives at
`tools/clang_format/clang-format.exe` and is also wired as a pre-commit hook.

## ⚠️ Status and limitations

- **Driver VID/PID**: stock PEAK drivers match `0C72:000C`; add `0483:000C` to the
  driver's device table (or use host software that opens the device by ID) first.
- **Single channel**: one CAN controller, no CAN FD, no ISO-TP — protocol layers such as
  ISO-TP or CANopen belong on the host.
- **Register model**: SJA1000 reads return shadow values; CAN error counters are not
  reported, and acceptance filtering is accept-all (32-bit mask filter).
- **Stubs**: `CFG`, `EXT_VCC`, `LED` mode and `SETCAN2FLASH` are accepted but do not
  change hardware; loopback exists in the CAN driver but is not exposed over USB.
- **Timestamps**: 16-bit 42.666 µs ticks wrap every ~2.8 s; the 1 Hz time-sync record is
  what lets host software reconstruct absolute time.

## 🤝 Contributing

Issues and pull requests are welcome. Please make sure a `debug` build stays warning-free
and format C sources with clang-format before opening a PR. CI builds the debug and release
CMake presets, the xmake release configuration, and the F7 USB-Ethernet demo. There is no
automated test suite yet —
hardware-in-the-loop testing on a real adapter is the reference.

## 📄 License

MIT. See [LICENSE](./LICENSE).

PCAN-USB is a trademark of PEAK-System Technik GmbH. This project is not affiliated with
or endorsed by PEAK-System.

---

<div align="center">

**PCAN-USB on the wire, a few kilobytes of Cortex-M0 on the board.**

[⭐ Star on GitHub](https://github.com/zhaojiale2021/USB2X) · [🐛 Report Issues](https://github.com/zhaojiale2021/USB2X/issues)

</div>
