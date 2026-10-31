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

-- Source files that belong to ST (warnings are not ours to fix)
local hal_srcs = {
    "stm32f0xx_hal.c",
    "stm32f0xx_hal_can.c",
    "stm32f0xx_hal_cortex.c",
    "stm32f0xx_hal_dma.c",
    "stm32f0xx_hal_exti.c",
    "stm32f0xx_hal_flash.c",
    "stm32f0xx_hal_flash_ex.c",
    "stm32f0xx_hal_gpio.c",
    "stm32f0xx_hal_pcd.c",
    "stm32f0xx_hal_pcd_ex.c",
    "stm32f0xx_hal_pwr.c",
    "stm32f0xx_hal_pwr_ex.c",
    "stm32f0xx_hal_rcc.c",
    "stm32f0xx_hal_rcc_ex.c",
    "stm32f0xx_hal_tim.c",
    "stm32f0xx_hal_tim_ex.c",
    "stm32f0xx_ll_usb.c"
}

local usb_srcs = {
    "usbd_core.c",
    "usbd_ctlreq.c",
    "usbd_ioreq.c"
}

target("USB2X")
    set_kind("binary")
    set_toolchains("stm32-gcc")
    set_languages("gnu11")
    set_filename("USB2X.elf")
    set_targetdir(outdir)

    -- Application sources
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

    -- HAL Driver (third-party)
    local hal = path.join(root, "lib/STM32CubeF0/Drivers/STM32F0xx_HAL_Driver/Src")
    for _, name in ipairs(hal_srcs) do
        add_files(path.join(hal, name), {cflags = "-w"})
    end

    -- USB Middleware (third-party)
    local usb = path.join(root, "lib/STM32CubeF0/Middlewares/ST/STM32_USB_Device_Library/Core/Src")
    for _, name in ipairs(usb_srcs) do
        add_files(path.join(usb, name), {cflags = "-w"})
    end

    -- Include directories (our headers)
    add_includedirs(path.join(root, "include"))
    -- System include directories (HAL / Middleware — suppress third-party warnings)
    add_sysincludedirs(path.join(root, "lib/STM32CubeF0/Middlewares/ST/STM32_USB_Device_Library/Core/Inc"))
    add_sysincludedirs(path.join(root, "lib/STM32CubeF0/Drivers/CMSIS/Core/Include"))
    add_sysincludedirs(path.join(root, "lib/STM32CubeF0/Drivers/CMSIS/Include"))
    add_sysincludedirs(path.join(root, "lib/STM32CubeF0/Drivers/CMSIS/Device/ST/STM32F0xx/Include"))
    add_sysincludedirs(path.join(root, "lib/STM32CubeF0/Drivers/STM32F0xx_HAL_Driver/Inc"))

    -- Preprocessor defines
    add_defines("STM32F072xB", "USE_HAL_DRIVER")
    add_defines(get_config("variant") or "CANABLE")

    -- Cortex-M0 CPU flags and section-level dead-code elimination
    add_cxflags("-mcpu=cortex-m0", "-mthumb", "-mfloat-abi=soft",
                "-ffunction-sections", "-fdata-sections")
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
                "--specs=nosys.specs", "-Wl,--gc-sections", "-Wl,--no-warn-rwx-segments",
                "-T" .. path.join(root, "src/startup/STM32F072XB_FLASH.ld"),
                "-Wl,-Map=" .. path.join(root, "build", "USB2X.map"),
                {force = true})

    -- Copy .map to output directory (which exists after xmake places the .elf there)
    after_build(function(target)
        local map = path.join(root, "build", "USB2X.map")
        if os.isfile(map) then
            os.cp(map, target:targetdir())
        end
    end)
