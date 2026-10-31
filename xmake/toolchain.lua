-- Toolchain: arm-none-eabi-gcc (Cortex-M0)
--
-- Toolchain lookup order:
--   1. ARM_GCC_BIN environment variable
--   2. STM32CubeIDE 1.15.0 bundled toolchain (default development setup)
--   3. arm-none-eabi-* found on PATH (CI / package-manager installs)

local default_bin =
    "D:/STM32CubeIDE_1.15.0/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.12.3.rel1.win32_1.0.100.202403111256/tools/bin"

local env_bin = os.getenv("ARM_GCC_BIN")
local gcc_bin
if env_bin and os.isdir(env_bin) then
    gcc_bin = env_bin
elseif os.isdir(default_bin) then
    gcc_bin = default_bin
end

local function tool(name)
    if gcc_bin then
        return path.join(gcc_bin, name)
    end
    return name
end

toolchain("stm32-gcc")
    set_kind("standalone")
    set_toolset("cc",      tool("arm-none-eabi-gcc"))
    set_toolset("as",      tool("arm-none-eabi-gcc"))
    set_toolset("ld",      tool("arm-none-eabi-gcc"))
    set_toolset("ar",      tool("arm-none-eabi-ar"))
    set_toolset("objcopy", tool("arm-none-eabi-objcopy"))
    set_toolset("strip",   tool("arm-none-eabi-strip"))
    set_toolset("sh",      tool("arm-none-eabi-size"))
toolchain_end()
