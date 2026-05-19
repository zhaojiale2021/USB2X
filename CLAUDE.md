# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

USB2X is an STM32F0xx firmware implementing a USB-to-CAN bus adapter that emulates the PEAK PCAN-USB protocol. The device appears as "XCAN-USB" (VID 0x0483, PID 0x000C) to the host and communicates CAN frames over USB bulk endpoints using a command set compatible with the SJA1000 register model.

## Build

Use `build.sh` (wraps CMake presets):

```
./build.sh              # debug config + build (default)
./build.sh release      # release config + build
./build.sh clean        # remove build/
./build.sh debug config # configure only
./build.sh debug build  # build without reconfiguring
```

CMake presets are defined in `CMakePresets.json`: `debug`, `release`, `minsize`, `reldebug`. All use Ninja generator and output to `build/`.

The toolchain is `arm-none-eabi-gcc` (Cortex-M0) from STM32CubeIDE 1.15.0, set via `CMakePresets.json` → `CMAKE_TOOLCHAIN_FILE`. Outputs: `build/bin/<BuildType>/USB2X.elf` and `USB2X.map`.

Build variants are selected via preprocessor defines passed at compile time. Supported variants: `CANABLE`, `ENTREE`, `CANTACT_8`, `CANTACT_16`, `OLLIE` — these define pin mappings and optional voltage regulator control in `include/pcan_varian.h`.

Code formatting uses clang-format (Google style, 120 columns). The binary and pre-commit hook live in `tools/clang_format/`.

## ## Dependencies

STM32 official code (CMSIS, HAL Driver, USB Device Library) is managed as a git submodule:

```
git submodule add git@github.com:STMicroelectronics/STM32CubeF0.git lib/STM32CubeF0
```

After cloning this repo, initialize with:

```
git submodule update --init --recursive
```

GitHub access uses SSH (HTTPS→SSH rewrite configured globally via `url.insteadof`).

## Architecture

The firmware uses a **polled super-loop** (no RTOS):

```
main() → init clocks/HAL/USB/CAN/LED/timestamp
       → loop { pcan_usb_poll(), pcan_led_poll(), pcan_protocol_poll() }
```

**USB layer** (`pcan_usb.c`): 4 bulk endpoints — CMD OUT/IN (16 bytes) for control commands, MSG OUT/IN (64 bytes) for CAN data frames. Uses the STM32 USB Device Library middleware.

**Protocol layer** (`pcan_protocol.c`): Decodes PCAN commands (SJA1000 register read/write, bitrate config, device info, LED control) and marshals CAN frames between USB packets and the CAN driver.

**CAN driver** (`pcan_can.c`): Wraps the STM32 HAL bxCAN peripheral for TX/RX with standard/extended IDs, RTR frames, configurable bitrates, and silent/loopback modes.

**Supporting modules**:
- `pcan_timestamp.c` — TIM3-based 42.666 µs tick counter plus SysTick milliseconds for CAN frame timestamps
- `pcan_led.c` — TX/RX/STAT LED patterns (on, off, fast blink 50 ms, slow blink 200 ms)
- `pcan_varian.h` — board-specific pin definitions selected by compile-time variant macro
- `pcan_packet.h` — protocol constants: command IDs, SJA1000 register map, error flags
- `punker.h` — little-endian pack/unpack macros (u8 through u32, float)
- `io_macro.h` — GPIO helper macros wrapping HAL calls

The `toolchains/` directory contains the STM32 Cortex-M0 toolchain configuration (`stm32_toolchain.cmake`).

## Tooling

- **Editor**: VS Code with clangd (IntelliSense disabled). `compile_commands.json` is generated in `build/`.
- **Formatting**: On-paste/on-type enabled. clang-format binary at `tools/clang_format/clang-format.exe`.
- **Debugging**: Debug build type adds `-g -Wall -Wextra`. Use STM32CubeIDE or an SWD probe for on-chip debugging.
