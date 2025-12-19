#!/bin/bash

# Build script for libvpx

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="libvpx"
REPO_URL="https://chromium.googlesource.com/webm/libvpx.git"

build_libvpx() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${LIBVPX_VERSION:-latest}"

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
    ./configure --prefix="$ffmpeg_build" \
        --disable-examples \
        --disable-unit-tests \
        --enable-vp9-highbitdepth \
        --enable-shared \
        --as=yasm

    log_info "Compiling $LIB_NAME..."
    run_make

    log_info "Installing $LIB_NAME..."
    make install

    # Fix dylib install name (libvpx uses relative path by default)
    log_info "Fixing dylib install name for $LIB_NAME..."
    local dylib_file="$ffmpeg_build/lib/libvpx.dylib"
    if [ -f "$dylib_file" ]; then
        local real_file=$(readlink -f "$dylib_file" 2>/dev/null || greadlink -f "$dylib_file" 2>/dev/null || echo "$dylib_file")
        local dylib_name=$(basename "$real_file")
        install_name_tool -id "$ffmpeg_build/lib/$dylib_name" "$real_file" 2>/dev/null || true
    fi

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
    build_libvpx "$1" "$2"
fi
