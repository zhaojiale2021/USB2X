# clear && cmake -G "Ninja" -DCMAKE_EXPORT_COMPILE_COMMANDS=1 .. && ninja clean && ninja -v

set(TARGET_CPU "rh850g4mh")
set(GHS_TOOLSET_ROOT "C:/ghs")

set(CMAKE_C_COMPILER_WORKS TRUE CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER_WORKS TRUE CACHE INTERNAL "")
set(CMAKE_C_COMPILER_FORCED TRUE CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER_FORCED TRUE CACHE INTERNAL "")
set(CMAKE_C_COMPILER_ID_RUN TRUE CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER_ID_RUN TRUE CACHE INTERNAL "")

set(CMAKE_C_COMPILER "C:/ghs/comp_202115/ccv850.exe")
set(CMAKE_CXX_COMPILER "C:/ghs/comp_202115/cxv850.exe")
set(CMAKE_ASM_COMPILER "C:/ghs/comp_202115/ccv850.exe")
set(CMAKE_AR "C:/ghs/comp_202115/cxv850.exe")
set(CMAKE_LINKER "C:/ghs/comp_202115/elxr.exe")
set(CMAKE_SREC "C:/ghs/comp_202115/gsrec.exe")



# Set common flags for compiler and linker
set(GHS_COMMON_FLAGS "")
list(APPEND GHS_COMMON_FLAGS
    "-cpu=${TARGET_CPU}"
    "-bsp=generic"
    "-sda=ALL"
    "-list"
    "-v850_isr_save_r4r5"
    "-large_sda"
    "-large_zda"
    "-ghsmc_core_count=2"
    "-dwarf2"
    "-fnofunctions"
    "-no_init_ram_at_startup"
    "-kanji=utf8"
)

# Set compiler flags
set(GHS_COMPILER_FLAGS "")
list(APPEND GHS_COMPILER_FLAGS
    ${GHS_COMMON_FLAGS}
    "-farcalls"

    "-Wimplicit-int" # implicit return type
    "-Wundef"        # undefined preprocessor symbols

    # "--Werror"       # warnings being treated as errors

    "--diag_suppress=177" #177-D:  variable "xxx" was declared but never referenced
    "--diag_suppress=550" #550-D:  variable "xxx" was set but never used
)

# Set c compiler flags
set(GHS_C_COMPILER_FLAGS "")
list(APPEND GHS_C_COMPILER_FLAGS
    ${GHS_COMPILER_FLAGS}
    "--no_short_enum"
)

# Set c++ compiler flags
set(GHS_CXX_COMPILER_FLAGS "")
list(APPEND GHS_CXX_COMPILER_FLAGS
    ${GHS_COMPILER_FLAGS}
    "-language=cxx"
    "--c++17"
    "--using_std"
    "--new_style_casts"
    "--enable_noinline"
    "--restrict"
    "--no_implicit_typename"
    "--standard_vtbl"
    "--no_guiding_decls"
)

# Set linker flags
set(GHS_LINKER_FLAGS "")
list(APPEND GHS_LINKER_FLAGS
    ${GHS_COMMON_FLAGS}
    "-language=c"
    "-language=cxx"
    "-e _RESET"
    "-ignore_debug_references"
    "-shorten_loads"                                                                 
    "-locatedprogram"
    "-paddr_offset=0"
)

# Set CMAKE_C_FLAGS
list(JOIN GHS_C_COMPILER_FLAGS " " GHS_C_COMPILER_FLAGS_STRING)
set(CMAKE_C_FLAGS_INIT   "${GHS_C_COMPILER_FLAGS_STRING}")

# Set CMAKE_CXX_FLAGS
list(JOIN GHS_CXX_COMPILER_FLAGS " " GHS_CXX_COMPILER_FLAGS_STRING)
set(CMAKE_CXX_FLAGS_INIT "${GHS_CXX_COMPILER_FLAGS_STRING}")

# Set CMAKE_ASM_FLAGS
set(CMAKE_ASM_FLAGS_INIT "-cpu=${TARGET_CPU}")

# Set Linker Flags
list(JOIN GHS_LINKER_FLAGS " " GHS_LINKER_FLAGS_STRING)
set(CMAKE_EXE_LINKER_FLAGS_INIT "${GHS_LINKER_FLAGS_STRING} ${ZX_PROJECT_LINKER_FILE} -MD ")

# Set debug and release flags
set(CMAKE_C_FLAGS_DEBUG "-Omoredebug -G")
set(CMAKE_C_FLAGS_RELEASE "-Ogeneral --no_debug")
set(CMAKE_CXX_FLAGS_DEBUG "-Omoredebug -G")
set(CMAKE_CXX_FLAGS_RELEASE "-Ogeneral --no_debug")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG "-Omoredebug -G")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "-Ogeneral --no_debug")

# Set Archive command
set(CMAKE_C_ARCHIVE_CREATE "<CMAKE_AR> -merge_archive --whole-archive -o <TARGET> <LINK_FLAGS> <OBJECTS>")
set(CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> -merge_archive --whole-archive -o <TARGET> <LINK_FLAGS> <OBJECTS>")

set(C_STANDARD_REQUIRED ON)
set(C_STANDARD 11)

set(CXX_STANDARD_REQUIRED ON)
set(CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXECUTABLE_SUFFIX_C   .elf)
set(CMAKE_EXECUTABLE_SUFFIX_CXX .elf)
set(CMAKE_EXECUTABLE_SUFFIX_ASM .elf)