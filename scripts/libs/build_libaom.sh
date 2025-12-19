#!/bin/bash

# Build script for libaom

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="libaom"
REPO_URL="https://aomedia.googlesource.com/aom"

build_libaom() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${LIBAOM_VERSION:-latest}"

    log_step "Building $LIB_NAME (version: $version)"

    local source_dir="$ffmpeg_sources/aom"
    local build_marker=$(get_build_marker "$ffmpeg_build" "$LIB_NAME")

    # Check if rebuild is needed
    if ! is_force_rebuild && ! needs_rebuild "$LIB_NAME" "$source_dir" "$build_marker"; then
        log_info "$LIB_NAME is up to date, skipping"
        return 0
    fi

    # Clone or update repository
    git_clone_or_update "$REPO_URL" "$source_dir" "$version" || {
        log_error "Failed to clone/update $LIB_NAME"
        return 1
    }

    # Build
    cd "$source_dir"

    # Restore build/cmake directory if it was deleted (required for aom build)
    if [ ! -d "build/cmake" ]; then
        log_info "Restoring build/cmake directory..."
        git restore build/ 2>/dev/null || true
    fi

    # Clean build artifacts but preserve build/cmake directory
    rm -rf build/CMakeCache.txt build/CMakeFiles build/*.dylib build/*.a 2>/dev/null || true
    mkdir -p build
    cd build

    log_info "Configuring $LIB_NAME..."
    cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX="$ffmpeg_build" \
        -DCMAKE_INSTALL_NAME_DIR="$ffmpeg_build/lib" \
        -DBUILD_SHARED_LIBS=1 \
        -DENABLE_NASM=on \
        ..

    log_info "Compiling $LIB_NAME..."
    run_make

    log_info "Installing $LIB_NAME..."
    make install

    # Fix dylib install name (libaom may use relative paths)
    log_info "Fixing dylib install name for $LIB_NAME..."
    for dylib in "$ffmpeg_build/lib"/libaom*.dylib; do
        if [ -f "$dylib" ] && [ ! -L "$dylib" ]; then
            local dylib_name=$(basename "$dylib")
            install_name_tool -id "$ffmpeg_build/lib/$dylib_name" "$dylib" 2>/dev/null || true
        fi
    done

    # Mark as built
    mark_built "$LIB_NAME" "$build_marker" "$version"
    log_success "$LIB_NAME build completed"

    return 0
}

# If script is run directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <ffmpeg_sources> <ffmpeg_build>"
        exit 1
    fi
    build_libaom "$1" "$2"
fi
