#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

usage() {
    echo "Usage: ./build.sh [preset|clean] [command]"
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
    echo "Examples:"
    echo "  ./build.sh                  # debug config + build"
    echo "  ./build.sh release          # release config + build"
    echo "  ./build.sh debug config     # debug configure only"
    echo "  ./build.sh clean            # remove build/"
}

# Allow "clean" as the first argument
if [ "$1" = "clean" ]; then
    rm -rf "$SCRIPT_DIR/build"
    echo "build/ removed"
    exit 0
fi

PRESET="${1:-debug}"
CMD="${2:-all}"

case "$CMD" in
    all)
        cmake --preset "$PRESET" -S "$SCRIPT_DIR"
        cmake --build --preset "$PRESET"
        ;;
    config)
        cmake --preset "$PRESET" -S "$SCRIPT_DIR"
        ;;
    build)
        cmake --build --preset "$PRESET"
        ;;
    clean)
        rm -rf "$SCRIPT_DIR/build"
        echo "build/ removed"
        ;;
    *)
        usage
        exit 1
        ;;
esac
