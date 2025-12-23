#!/bin/bash

# Build script for libjxl

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="libjxl"
REPO_URL="https://github.com/libjxl/libjxl.git"

build_libjxl() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${LIBJXL_VERSION:-latest}"

    log_step "Building $LIB_NAME (version: $version)"

    local source_dir="$ffmpeg_sources/$LIB_NAME"
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
    
    # Initialize submodules (important for libjxl to bundle dependencies like highway/brotli if not found)
    log_info "Updating submodules for $LIB_NAME..."
    git submodule update --init --recursive

    rm -rf build
    mkdir -p build
    cd build

    log_info "Configuring $LIB_NAME with CMake..."

    # Set build type based on debug mode
    local build_type="Release"
    if is_debug_enabled; then
        build_type="Debug"
    fi

    # We enforce bundled dependencies (hwy, brotli) if we want to be self-contained, 
    # or let it find system ones. For stability in this build script, 
    # let's try to use bundled ones if system ones are tricky, but libjxl defaults are usually sane.
    # However, to avoid 'package not found' issues if the user doesn't have them, 
    # using submodules (which we updated) and letting cmake use them is good.
    # By default libjxl checks system first, then falls back to internal if flags allow.
    # We will enable shared libs to match other libs.

    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$ffmpeg_build" \
        -DCMAKE_BUILD_TYPE="$build_type" \
        -DBUILD_SHARED_LIBS=ON \
        -DJPEGXL_ENABLE_PLUGINS=OFF \
        -DJPEGXL_ENABLE_BENCHMARK=OFF \
        -DJPEGXL_ENABLE_EXAMPLES=OFF \
        -DJPEGXL_ENABLE_MANPAGES=OFF \
        -DJPEGXL_ENABLE_SJPEG=OFF \
        -DJPEGXL_ENABLE_SKCMS=ON 

    log_info "Compiling $LIB_NAME..."
    run_make

    log_info "Installing $LIB_NAME..."
    make install

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
    build_libjxl "$1" "$2"
fi
