cmake_minimum_required(VERSION 3.20)

# TinyUSB is vendored as a git submodule. Override with -DTINYUSB_DIR=... if needed.
set(TINYUSB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../lib/tinyusb" CACHE PATH "TinyUSB root")
if(NOT EXISTS "${TINYUSB_DIR}/hw/bsp/family_support.cmake")
    message(FATAL_ERROR "TinyUSB not found at ${TINYUSB_DIR}. Run: git submodule update --init lib/tinyusb")
endif()

# Resolve the ARM toolchain before TinyUSB's toolchain file is loaded.
if(NOT DEFINED CMAKE_C_COMPILER)
    set(_arm_gcc_paths "")
    if(DEFINED ENV{ARM_GCC_BIN})
        list(APPEND _arm_gcc_paths "$ENV{ARM_GCC_BIN}")
    endif()
    if(CMAKE_HOST_WIN32)
        list(APPEND _arm_gcc_paths
            "D:/STM32CubeIDE_1.15.0/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.12.3.rel1.win32_1.0.100.202403111256/tools/bin")
    endif()
    find_program(_ARM_GCC arm-none-eabi-gcc PATHS ${_arm_gcc_paths} NO_DEFAULT_PATH)
    if(NOT _ARM_GCC)
        find_program(_ARM_GCC arm-none-eabi-gcc)
    endif()
    if(NOT _ARM_GCC)
        message(FATAL_ERROR "arm-none-eabi-gcc not found. Set ARM_GCC_BIN or add it to PATH.")
    endif()
    set(CMAKE_C_COMPILER "${_ARM_GCC}")
    get_filename_component(_ARM_GCC_DIR "${_ARM_GCC}" DIRECTORY)
    get_filename_component(_ARM_GCC_EXT "${_ARM_GCC}" EXT)
    set(CMAKE_CXX_COMPILER "${_ARM_GCC_DIR}/arm-none-eabi-g++${_ARM_GCC_EXT}")
endif()

include("${TINYUSB_DIR}/hw/bsp/family_support.cmake")

project(usb_eth_f7 C CXX ASM)

family_initialize_project(${PROJECT_NAME} ${CMAKE_CURRENT_LIST_DIR})

# Reuse the CMSIS Core headers already present in the STM32CubeF0 submodule
# instead of fetching another CMSIS_5 tree.
set(CMSIS_5 "${CMAKE_CURRENT_SOURCE_DIR}/../../lib/STM32CubeF0/Drivers")

# Ethernet DMA descriptors and buffers must be in SRAM1, not DTCM.
set(LD_FILE_GNU "${CMAKE_CURRENT_LIST_DIR}/linker/STM32F746ZGTx_FLASH.ld")

add_executable(${PROJECT_NAME})

target_sources(${PROJECT_NAME} PRIVATE
    src/main.c
    src/usb_descriptors.c
    src/eth_bridge.c
    src/eth_msp.c
    ${TOP}/hw/mcu/st/stm32f7xx_hal_driver/Src/stm32f7xx_hal_eth.c
)

target_include_directories(${PROJECT_NAME} PRIVATE src)

# ST HAL is third-party code; do not fail the demo build on its warnings.
set_source_files_properties(
    ${TOP}/hw/mcu/st/stm32f7xx_hal_driver/Src/stm32f7xx_hal_eth.c
    PROPERTIES COMPILE_OPTIONS "-w"
)

family_configure_device_example(${PROJECT_NAME} noos)

# TinyUSB's family build enables -Werror. Keep the demo buildable with newer
# GCC versions and third-party warnings; our own code is still warning-free.
target_compile_options(${PROJECT_NAME} PRIVATE -Wno-error)
