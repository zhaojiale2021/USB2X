cmake_minimum_required(VERSION 3.24)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/toolchains")

set(PROJECT_TARGET_BIN_NAME USB2X)

# Only set toolchain if not already specified on command line
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "${CMAKE_MODULE_PATH}/stm32_toolchain.cmake")
endif()

project(${PROJECT_TARGET_BIN_NAME} LANGUAGES C CXX ASM)

# Board variant selection (default: CANABLE)
# Supported: CANABLE, ENTREE, CANTACT_8, CANTACT_16, OLLIE
set(VARIANT "CANABLE" CACHE STRING "Target board variant")
set_property(CACHE VARIANT PROPERTY STRINGS "CANABLE" "ENTREE" "CANTACT_8" "CANTACT_16" "OLLIE")
include(${PROJECT_SOURCE_DIR}/presets/${VARIANT}.cmake)

set(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/build/bin/${CMAKE_BUILD_TYPE})

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    message(STATUS "Setting build type to 'Release' as none was specified.")
    set(CMAKE_BUILD_TYPE Release CACHE STRING
        "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel."
        FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

message(STATUS "Current build type is ${CMAKE_BUILD_TYPE}")

###############################################################################
# Sources
###############################################################################

set(_submod "lib/STM32CubeF0")
set(_microchip "STM32F0xx")
set(_hal_dir "${_submod}/Drivers/${_microchip}_HAL_Driver/Src")

# HAL Driver sources
set(HAL_SRCS
    ${_hal_dir}/stm32f0xx_hal.c
    ${_hal_dir}/stm32f0xx_hal_can.c
    ${_hal_dir}/stm32f0xx_hal_cortex.c
    ${_hal_dir}/stm32f0xx_hal_dma.c
    ${_hal_dir}/stm32f0xx_hal_exti.c
    ${_hal_dir}/stm32f0xx_hal_flash.c
    ${_hal_dir}/stm32f0xx_hal_flash_ex.c
    ${_hal_dir}/stm32f0xx_hal_gpio.c
    ${_hal_dir}/stm32f0xx_hal_pcd.c
    ${_hal_dir}/stm32f0xx_hal_pcd_ex.c
    ${_hal_dir}/stm32f0xx_hal_pwr.c
    ${_hal_dir}/stm32f0xx_hal_pwr_ex.c
    ${_hal_dir}/stm32f0xx_hal_rcc.c
    ${_hal_dir}/stm32f0xx_hal_rcc_ex.c
    ${_hal_dir}/stm32f0xx_hal_tim.c
    ${_hal_dir}/stm32f0xx_hal_tim_ex.c
    ${_hal_dir}/stm32f0xx_ll_usb.c
)

# Application sources
set(APP_SRCS
    src/c/main.c
    src/c/system_stm32f0xx.c
    src/c/pcan_usb.c
    src/c/pcan_protocol.c
    src/c/pcan_can.c
    src/c/pcan_led.c
    src/c/pcan_timestamp.c
    src/c/usbd_conf.c
    src/c/usbd_desc.c
)

# USB Middleware sources
set(USB_SRCS
    ${_submod}/Middlewares/ST/STM32_USB_Device_Library/Core/Src/usbd_core.c
    ${_submod}/Middlewares/ST/STM32_USB_Device_Library/Core/Src/usbd_ctlreq.c
    ${_submod}/Middlewares/ST/STM32_USB_Device_Library/Core/Src/usbd_ioreq.c
)

# Startup
set(STARTUP_SRCS
    src/startup/startup_stm32f072xb.s
)

set(SRCS ${STARTUP_SRCS} ${APP_SRCS} ${USB_SRCS} ${HAL_SRCS})

#=============================================================================
# Executable Declaration
#=============================================================================
add_executable(${PROJECT_TARGET_BIN_NAME} ${SRCS})

target_include_directories(
    ${PROJECT_TARGET_BIN_NAME}
    PUBLIC
        ${PROJECT_SOURCE_DIR}/include
    SYSTEM
        ${PROJECT_SOURCE_DIR}/${_submod}/Middlewares/ST/STM32_USB_Device_Library/Core/Inc
        ${PROJECT_SOURCE_DIR}/${_submod}/Drivers/CMSIS/Core/Include
        ${PROJECT_SOURCE_DIR}/${_submod}/Drivers/CMSIS/Include
        ${PROJECT_SOURCE_DIR}/${_submod}/Drivers/CMSIS/Device/ST/${_microchip}/Include
        ${PROJECT_SOURCE_DIR}/${_submod}/Drivers/${_microchip}_HAL_Driver/Inc
)

target_compile_definitions(
    ${PROJECT_TARGET_BIN_NAME}
    PRIVATE
        STM32F072xB
        ${BOARD_VARIANT}
        USE_HAL_DRIVER
)

# Common CPU flags for Cortex-M0
set(CPU_FLAGS "-mcpu=cortex-m0 -mthumb -mfloat-abi=soft")
set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} ${CPU_FLAGS}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CPU_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CPU_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${CPU_FLAGS} --specs=nosys.specs -Wl,--gc-sections")

set_target_properties(${PROJECT_TARGET_BIN_NAME} PROPERTIES
    SUFFIX ".elf"
)

target_link_options(${PROJECT_TARGET_BIN_NAME} PRIVATE
    -T${PROJECT_SOURCE_DIR}/src/startup/STM32F072XB_FLASH.ld
    -Wl,-Map=${EXECUTABLE_OUTPUT_PATH}/${PROJECT_TARGET_BIN_NAME}.map
)

# Build specific compile options
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(${PROJECT_TARGET_BIN_NAME} PRIVATE -g -Wall -Wextra -Wno-unused-parameter)
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    target_compile_options(${PROJECT_TARGET_BIN_NAME} PRIVATE -g -Wall -Wextra -O2 -Wno-unused-parameter)
elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
    target_compile_options(${PROJECT_TARGET_BIN_NAME} PRIVATE -Os -Wall -Wextra -Wno-unused-parameter)
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(${PROJECT_TARGET_BIN_NAME} PRIVATE -O2 -Wall -Wextra -Wno-unused-parameter)
endif()
