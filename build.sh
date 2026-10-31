#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PRESETS="debug release minsize reldebug"
VARIANTS="CANABLE ENTREE CANTACT_8 CANTACT_16 OLLIE"

usage() {
    echo "Usage: ./build.sh [preset|clean] [command] [variant]"
    echo ""
    echo "Presets (from CMakePresets.json):"
    echo "  debug       Debug build (default)"
    echo "  release     Release build -O2"
    echo "  minsize     MinSizeRel build -Os"
    echo "  reldebug    RelWithDebInfo build -O2 -g"
    echo ""
    echo "Commands:"
    echo "  all     Configure + build (default)"
    echo "  config  CMake configure only"
    echo "  build   CMake build only"
    echo "  clean   Remove build directory"
    echo ""
    echo "Variants (board presets):"
    echo "  CANABLE      Generic CAN-USB adapter (default)"
    echo "  ENTREE       Entree variant"
    echo "  CANTACT_8    Cantact 8MHz variant"
    echo "  CANTACT_16   Cantact 16MHz variant"
    echo "  OLLIE        Ollie variant (voltage regulator control)"
    echo ""
    echo "Examples:"
    echo "  ./build.sh                      # debug config + build (CANABLE)"
    echo "  ./build.sh release              # release config + build (CANABLE)"
    echo "  ./build.sh debug all OLLIE      # debug build with OLLIE variant"
    echo "  ./build.sh clean                # remove build/"
}

in_list() {
    case " $1 " in
        *" $2 "*) return 0 ;;
        *) return 1 ;;
    esac
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Allow "clean" as the first argument
if [[ "${1:-}" == "clean" && $# -eq 1 ]]; then
    rm -rf "$SCRIPT_DIR/build"
    echo "build/ removed"
    exit 0
fi

PRESET="${1:-debug}"
CMD="${2:-all}"
VARIANT="${3:-}"

if ! in_list "$PRESETS" "$PRESET"; then
    echo "Unknown preset: $PRESET" >&2
    usage
    exit 1
fi

if ! in_list "all config build clean" "$CMD"; then
    echo "Unknown command: $CMD" >&2
    usage
    exit 1
fi

if [[ -n "$VARIANT" ]]; then
    if ! in_list "$VARIANTS" "$VARIANT"; then
        echo "Unknown variant: $VARIANT" >&2
        usage
        exit 1
    fi
    if [[ "$CMD" != "all" && "$CMD" != "config" ]]; then
        echo "warning: variant '$VARIANT' is only applied when configuring (command: $CMD)" >&2
    fi
fi

CMAKE_ARGS=(--preset "$PRESET" -S "$SCRIPT_DIR")
if [[ -n "$VARIANT" ]]; then
    CMAKE_ARGS+=("-DVARIANT=$VARIANT")
fi

case "$CMD" in
    all)
        cmake "${CMAKE_ARGS[@]}"
        cmake --build --preset "$PRESET"
        ;;
    config)
        cmake "${CMAKE_ARGS[@]}"
        ;;
    build)
        cmake --build --preset "$PRESET"
        ;;
    clean)
        rm -rf "$SCRIPT_DIR/build"
        echo "build/ removed"
        ;;
esac
