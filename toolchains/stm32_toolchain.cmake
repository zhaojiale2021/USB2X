# Toolchain: arm-none-eabi-gcc for STM32 Cortex-M0
#
# Toolchain lookup order:
#   1. ARM_GCC_BIN environment variable (directory containing arm-none-eabi-*)
#   2. STM32CubeIDE 1.15.0 bundled GCC (default development setup)
#   3. arm-none-eabi-gcc found on PATH (CI / package-manager installs)

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(_arm_gcc_search_paths "")
if(DEFINED ENV{ARM_GCC_BIN})
    list(APPEND _arm_gcc_search_paths "$ENV{ARM_GCC_BIN}")
endif()
list(APPEND _arm_gcc_search_paths
    "D:/STM32CubeIDE_1.15.0/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.12.3.rel1.win32_1.0.100.202403111256/tools/bin")

find_program(ARM_GCC_EXECUTABLE arm-none-eabi-gcc PATHS ${_arm_gcc_search_paths} NO_DEFAULT_PATH)
if(NOT ARM_GCC_EXECUTABLE)
    find_program(ARM_GCC_EXECUTABLE arm-none-eabi-gcc)
endif()
if(NOT ARM_GCC_EXECUTABLE)
    message(FATAL_ERROR "arm-none-eabi-gcc not found. Set ARM_GCC_BIN or add it to PATH.")
endif()

get_filename_component(_ARM_GCC_DIR "${ARM_GCC_EXECUTABLE}" DIRECTORY)
get_filename_component(_ARM_GCC_EXT "${ARM_GCC_EXECUTABLE}" EXT)

set(CMAKE_C_COMPILER "${_ARM_GCC_DIR}/arm-none-eabi-gcc${_ARM_GCC_EXT}")
set(CMAKE_ASM_COMPILER "${_ARM_GCC_DIR}/arm-none-eabi-gcc${_ARM_GCC_EXT}")
set(CMAKE_AR "${_ARM_GCC_DIR}/arm-none-eabi-ar${_ARM_GCC_EXT}")
set(CMAKE_LINKER "${_ARM_GCC_DIR}/arm-none-eabi-ld${_ARM_GCC_EXT}")
set(CMAKE_OBJCOPY "${_ARM_GCC_DIR}/arm-none-eabi-objcopy${_ARM_GCC_EXT}")
set(CMAKE_SIZE "${_ARM_GCC_DIR}/arm-none-eabi-size${_ARM_GCC_EXT}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
