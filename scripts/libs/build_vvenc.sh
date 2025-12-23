#!/bin/bash

# Build script for vvenc (VVC encoder)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="vvenc"
REPO_URL="https://github.com/fraunhoferhhi/vvenc.git"

build_vvenc() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${VVENC_VERSION:-latest}"

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
    log_info "Configuring $LIB_NAME..."
    local debug_flags=$(get_debug_flags)
    local release_flags=$(get_release_flags)
    
    # Get absolute path to build directory
    local abs_build_dir=$(cd "$ffmpeg_build" && pwd)

    # Create build directory
    rm -rf build
    mkdir -p build
    cd build

    # Configure with CMake
    export CMAKE_INSTALL_PREFIX="$abs_build_dir"
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DVVENC_ENABLE_LINK_TIME_OPTIMIZATION=ON \
        -DVVENC_ENABLE_PIC=ON \
        -DCMAKE_CXX_FLAGS="$debug_flags $release_flags" \
        -DCMAKE_C_FLAGS="$debug_flags $release_flags"

    log_info "Compiling $LIB_NAME..."
    run_make

    log_info "Installing $LIB_NAME..."
    make install

    # Fix vvenc install location
    source "$SCRIPT_DIR/fix_vvenc_install.sh"
    fix_vvenc_install "$ffmpeg_sources" "$ffmpeg_build"

    # Fix dylib IDs for macOS
    fix_dylib_id "$ffmpeg_build/lib/libvvenc.dylib"
    fix_dylib_id "$ffmpeg_build/lib/libvvdec.dylib"

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
    build_vvenc "$1" "$2"
fi