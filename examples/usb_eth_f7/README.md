# USB-Ethernet demo (STM32F746G-DISCO)

A USB CDC-NCM network adapter bridged to the on-board 100 Mbps Ethernet PHY
(LAN8742A). The MCU does **not** run TCP/IP: it forwards raw Ethernet frames
between TinyUSB's network class and the STM32F7 Ethernet MAC/DMA.

- **Target**: STM32F746G-DISCO — 216 MHz Cortex-M7, USB HS via ULPI,
  100 Mbps RMII PHY, on-board ST-LINK.
- **USB class**: TinyUSB CDC-NCM, including the Microsoft OS 2.0 descriptor so
  Windows loads its NCM driver automatically. Linux and macOS support NCM
  natively.
- **Ethernet**: STM32F7 HAL ETH in RMII mode, LAN8742A PHY, promiscuous mode.
- **No lwIP**: the host OS runs DHCP/IP/TCP; this firmware is a layer-2 bridge.

This is a separate application from the F072 PCAN firmware. Only the build
tooling and repository conventions are shared.

## Build

```bash
# From the repository root
git submodule update --init --recursive

# Fetch the STM32F7 HAL/CMSIS device drivers used by TinyUSB
python3 lib/tinyusb/tools/get_deps.py hw/mcu/st/cmsis_device_f7 hw/mcu/st/stm32f7xx_hal_driver

cmake -S examples/usb_eth_f7 -B examples/usb_eth_f7/build -G Ninja \
      -DBOARD=stm32f746disco -DCMAKE_BUILD_TYPE=Release
cmake --build examples/usb_eth_f7/build
```

Outputs in `examples/usb_eth_f7/build/`:

```
usb_eth_f7.elf
usb_eth_f7.bin
usb_eth_f7.hex
```

The toolchain is resolved from `ARM_GCC_BIN`, the STM32CubeIDE 1.15.0 path, or
`arm-none-eabi-gcc` on `PATH`. On Windows, use `python` if `python3` is not
available.

## Flash

Use the on-board ST-LINK with STM32CubeProgrammer or the `flash-stlink` build
target:

```bash
STM32_Programmer_CLI -c port=SWD -d examples/usb_eth_f7/build/usb_eth_f7.elf -rst
```

Plug the USB cable into the board's **USB OTG HS** connector (the one wired to
the ULPI PHY), not the OTG FS connector.

## Host side

- **Windows**: a new network adapter appears (NCM). It gets an address from the
  LAN's DHCP server through the Ethernet port, or assign a static IP.
- **Linux/macOS**: a `usb*` NCM interface appears; use it like any USB Ethernet
  adapter.
- Check the link: `ping` a device on the same Ethernet segment.

## Data path

```
Host OS (TCP/IP, DHCP)
    ↕ USB HS / CDC-NCM
TinyUSB net_device
    ↕ tud_network_* callbacks
eth_bridge.c (frame ring, TX queue)
    ↕ STM32F7 ETH HAL (DMA)
LAN8742A (RMII, 10/100)
    ↕
Ethernet
```

- **RX**: the ETH interrupt drains `HAL_ETH_ReadData()` into a 16-frame ring;
  the main loop copies frames into TinyUSB when it can accept them.
- **TX**: `tud_network_recv_cb()` copies the host frame into a DMA TX buffer and
  starts `HAL_ETH_Transmit_IT()`.
- The MAC runs in promiscuous mode because the host's MAC address is not known
  to the MCU. Broadcast and all multicast frames are passed.
- The USB MAC address is derived from the MCU UID with the locally-administered
  bit set.
- PHY link/speed/duplex is read from the LAN8742A BSR and reported to the host
  through `tud_network_link_state()`.

## Memory layout

The Ethernet DMA cannot access Cortex-M7 DTCM. The custom linker script
([`linker/STM32F746ZGTx_FLASH.ld`](linker/STM32F746ZGTx_FLASH.ld)) places
`.eth_dma` (RX/TX descriptors and buffers, ~19 KB) at `0x20040000` in SRAM1:

```
RAM     0x20000000  256K   application data/bss (DTCM + SRAM1)
ETH_DMA 0x20040000   32K   descriptors + DMA buffers
FLASH   0x08000000 1024K
```

Approximate Release footprint: 28 KB flash, 34 KB RAM (excluding the 19 KB
DMA region).

## Limitations

- **Compile-only in this repository.** CI builds it, but enumeration, Windows
  driver binding and throughput have not been validated on hardware here.
- Frames are dropped when the 16-frame RX ring or 4-slot TX queue is full.
  There is no flow control/backpressure beyond USB NACKs.
- Standard 1514-byte frames only; no VLAN, jumbo, or PTP support.
- `VID 0xCafe / PID 0x4018` are TinyUSB demo IDs; use a licensed VID/PID for a
  product.
- If Windows does not bind the NCM driver on your build, set `USE_ECM 1` in
  `src/tusb_config.h` to use the ECM/RNDIS variant and add
  `lib/networking/rndis_reports.c` to the target sources.

## Files

```
src/main.c              main loop + TinyUSB net_device callbacks
src/eth_bridge.c/.h     ETH init, DMA frame rings, PHY link handling
src/eth_msp.c           RMII GPIO/clock, ETH interrupt
src/stm32f7xx_hal_conf.h   HAL config with ETH enabled
src/tusb_config.h       NCM/ECM selection and TinyUSB settings
src/usb_descriptors.c   NCM descriptors + MS OS 2.0
linker/                 linker script with the ETH DMA region
CMakeLists.txt          TinyUSB family build integration
```

`tusb_config.h`, `usb_descriptors.c` and `stm32f7xx_hal_conf.h` are adapted from
TinyUSB/ST; they intentionally keep their upstream formatting.
