-- Toolchain: arm-none-eabi-gcc (Cortex-M0)
-- Override default path via ARM_GCC_BIN environment variable.
-- Default points to STM32CubeIDE 1.15.0 bundled toolchain.

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
