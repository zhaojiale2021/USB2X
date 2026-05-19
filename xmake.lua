-- xmake.lua
-- USB2X — STM32F072xB USB-to-CAN firmware (PEAK PCAN-USB protocol)
--
-- Usage:
--   xmake f -m debug [--variant=CANABLE]
--   xmake
--   xmake clean
--
-- Build modes mirror CMakePresets.json: debug, release, releasedbg, minsizerel

set_project("USB2X")
set_version("1.0.0")

add_rules("mode.debug", "mode.release", "mode.releasedbg", "mode.minsizerel")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "."})

includes("xmake/toolchain.lua")
includes("xmake/option.lua")
includes("xmake/target.lua")
