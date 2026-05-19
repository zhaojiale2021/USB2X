-- Target: USB2X firmware binary
-- Mirrors CMakeLists.txt — same sources, includes, defines, and flags.

local root = os.projectdir()

-- Map xmake mode names to CMake directory casing
local mode_dirs = {
    debug      = "Debug",
    release    = "Release",
    minsizerel = "MinSizeRel",
    releasedbg = "RelWithDebInfo"
}
local mode = get_config("mode") or "debug"
local outdir = path.join(root, "build/bin", mode_dirs[mode] or mode)

target("USB2X")
    set_kind("binary")
    set_toolchains("stm32-gcc")
    set_filename("USB2X.elf")
    set_targetdir(outdir)

    -- App sources
    add_files(path.join(root, "src/c/main.c"))
    add_files(path.join(root, "src/c/system_stm32f0xx.c"))
    add_files(path.join(root, "src/c/pcan_usb.c"))
    add_files(path.join(root, "src/c/pcan_protocol.c"))
    add_files(path.join(root, "src/c/pcan_can.c"))
    add_files(path.join(root, "src/c/pcan_led.c"))
    add_files(path.join(root, "src/c/pcan_timestamp.c"))
    add_files(path.join(root, "src/c/usbd_conf.c"))
    add_files(path.join(root, "src/c/usbd_desc.c"))

    -- Startup
    add_files(path.join(root, "src/startup/startup_stm32f072xb.s"))

    -- HAL Driver
    local hal = path.join(root, "lib/STM32CubeF0/Drivers/STM32F0xx_HAL_Driver/Src")
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
    local usb = path.join(root, "lib/STM32CubeF0/Middlewares/ST/STM32_USB_Device_Library/Core/Src")
    add_files(path.join(usb, "usbd_core.c"))
    add_files(path.join(usb, "usbd_ctlreq.c"))
    add_files(path.join(usb, "usbd_ioreq.c"))

    -- Include directories
    add_includedirs(path.join(root, "include"))
    add_includedirs(path.join(root, "lib/STM32CubeF0/Middlewares/ST/STM32_USB_Device_Library/Core/Inc"))
    add_includedirs(path.join(root, "lib/STM32CubeF0/Drivers/CMSIS/Core/Include"))
    add_includedirs(path.join(root, "lib/STM32CubeF0/Drivers/CMSIS/Include"))
    add_includedirs(path.join(root, "lib/STM32CubeF0/Drivers/CMSIS/Device/ST/STM32F0xx/Include"))
    add_includedirs(path.join(root, "lib/STM32CubeF0/Drivers/STM32F0xx_HAL_Driver/Inc"))

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

    -- Linker writes map to build/ (guaranteed to exist); xmake places .elf in outdir
    add_ldflags("-mcpu=cortex-m0", "-mthumb", "-mfloat-abi=soft",
                "--specs=nosys.specs", "-Wl,--gc-sections",
                "-T" .. path.join(root, "src/startup/STM32F072XB_FLASH.ld"),
                "-Wl,-Map=" .. path.join(root, "build", "USB2X.map"),
                {force = true})

    -- Copy .map to output directory (which exists after xmake places the .elf there)
    after_build(function(target)
        os.cp(path.join(root, "build", "USB2X.map"), target:targetdir())
    end)
