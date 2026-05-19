-- xmake.lua
-- USB2X — STM32F072xB USB-to-CAN firmware (PEAK PCAN-USB protocol)
--
-- Usage:
--   xmake f -m debug [--variant=CANABLE]
--   xmake
--
--   xmake f -m release --variant=OLLIE
--   xmake
--
--   xmake clean    — remove build artifacts

set_project("USB2X")
set_version("1.0.0")

----------------------------------------------
-- Options
----------------------------------------------

option("variant")
    set_default("CANABLE")
    set_values("CANABLE", "ENTREE", "CANTACT_8", "CANTACT_16", "OLLIE")
    set_description("Target board variant")
option_end()

----------------------------------------------
-- Build modes (mirror CMakePresets.json)
----------------------------------------------

add_rules("mode.debug", "mode.release", "mode.releasedbg", "mode.minsizerel")

----------------------------------------------
-- Toolchain: arm-none-eabi-gcc (Cortex-M0)
----------------------------------------------

local gcc_bin = os.getenv("ARM_GCC_BIN") or
    "D:/STM32CubeIDE_1.15.0/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.12.3.rel1.win32_1.0.100.202403111256/tools/bin"

toolchain("stm32-gcc")
    set_kind("standalone")
    set_toolset("cc",      path.join(gcc_bin, "arm-none-eabi-gcc"))
    set_toolset("cxx",     path.join(gcc_bin, "arm-none-eabi-g++"))
    set_toolset("as",      path.join(gcc_bin, "arm-none-eabi-gcc"))
    set_toolset("ld",      path.join(gcc_bin, "arm-none-eabi-gcc"))
    set_toolset("ar",      path.join(gcc_bin, "arm-none-eabi-ar"))
    set_toolset("objcopy", path.join(gcc_bin, "arm-none-eabi-objcopy"))
    set_toolset("strip",   path.join(gcc_bin, "arm-none-eabi-strip"))
    set_toolset("sh",      path.join(gcc_bin, "arm-none-eabi-size"))
toolchain_end()

----------------------------------------------
-- Target
----------------------------------------------

target("USB2X")
    set_kind("binary")
    set_toolchains("stm32-gcc")
    set_filename("USB2X.elf")
    set_targetdir("build/bin/$(mode)")

    -- App sources
    add_files("src/c/main.c")
    add_files("src/c/system_stm32f0xx.c")
    add_files("src/c/pcan_usb.c")
    add_files("src/c/pcan_protocol.c")
    add_files("src/c/pcan_can.c")
    add_files("src/c/pcan_led.c")
    add_files("src/c/pcan_timestamp.c")
    add_files("src/c/usbd_conf.c")
    add_files("src/c/usbd_desc.c")

    -- Startup
    add_files("src/startup/startup_stm32f072xb.s")

    -- HAL Driver
    local hal = "lib/STM32CubeF0/Drivers/STM32F0xx_HAL_Driver/Src"
    add_files(path.join(hal, "stm32f0xx_hal.c"))
    add_files(path.join(hal, "stm32f0xx_hal_can.c"))
    add_files(path.join(hal, "stm32f0xx_hal_cortex.c"))
    add_files(path.join(hal, "stm32f0xx_hal_dma.c"))
    add_files(path.join(hal, "stm32f0xx_hal_exti.c"))
    add_files(path.join(hal, "stm32f0xx_hal_flash.c"))
    add_files(path.join(hal, "stm32f0xx_hal_flash_ex.c"))
    add_files(path.join(hal, "stm32f0xx_hal_gpio.c"))
    add_files(path.join(hal, "stm32f0xx_hal_pcd.c"))
    add_files(path.join(hal, "stm32f0xx_hal_pcd_ex.c"))
    add_files(path.join(hal, "stm32f0xx_hal_pwr.c"))
    add_files(path.join(hal, "stm32f0xx_hal_pwr_ex.c"))
    add_files(path.join(hal, "stm32f0xx_hal_rcc.c"))
    add_files(path.join(hal, "stm32f0xx_hal_rcc_ex.c"))
    add_files(path.join(hal, "stm32f0xx_hal_tim.c"))
    add_files(path.join(hal, "stm32f0xx_hal_tim_ex.c"))
    add_files(path.join(hal, "stm32f0xx_ll_usb.c"))

    -- USB Middleware
    local usb = "lib/STM32CubeF0/Middlewares/ST/STM32_USB_Device_Library/Core/Src"
    add_files(path.join(usb, "usbd_core.c"))
    add_files(path.join(usb, "usbd_ctlreq.c"))
    add_files(path.join(usb, "usbd_ioreq.c"))

    -- Include directories
    add_includedirs("include")
    add_includedirs("lib/STM32CubeF0/Middlewares/ST/STM32_USB_Device_Library/Core/Inc")
    add_includedirs("lib/STM32CubeF0/Drivers/CMSIS/Core/Include")
    add_includedirs("lib/STM32CubeF0/Drivers/CMSIS/Include")
    add_includedirs("lib/STM32CubeF0/Drivers/CMSIS/Device/ST/STM32F0xx/Include")
    add_includedirs("lib/STM32CubeF0/Drivers/STM32F0xx_HAL_Driver/Inc")

    -- Preprocessor defines
    add_defines("STM32F072xB", "USE_HAL_DRIVER")
    add_defines(get_config("variant") or "CANABLE")

    -- Cortex-M0 CPU flags (all languages)
    add_cxflags("-mcpu=cortex-m0", "-mthumb", "-mfloat-abi=soft")
    add_asflags("-mcpu=cortex-m0", "-mthumb", "-mfloat-abi=soft")

    -- Build mode flags
    if is_mode("debug") then
        add_cxflags("-g", "-Wall", "-Wextra")
    elseif is_mode("release") then
        add_cxflags("-O2", "-Wall", "-Wextra")
    elseif is_mode("releasedbg") then
        add_cxflags("-O2", "-g", "-Wall", "-Wextra")
    elseif is_mode("minsizerel") then
        add_cxflags("-Os", "-Wall", "-Wextra")
    end

    -- Linker (force = true needed for CPU flags xmake would otherwise filter)
    add_ldflags("-mcpu=cortex-m0", "-mthumb", "-mfloat-abi=soft",
                "--specs=nosys.specs", "-Wl,--gc-sections",
                "-T$(projectdir)/src/startup/STM32F072XB_FLASH.ld",
                "-Wl,-Map=" .. path.join("$(builddir)", "USB2X.map"),
                {force = true})

    -- Generate .map file via objcopy (ensures it's always produced)
    after_build(function(target)
        local map = path.join(target:targetdir(), "USB2X.map")
        print("Output: " .. target:targetfile())
        print("Map:    " .. map)
    end)
