#!/bin/bash

# Build script for FFmpeg

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="ffmpeg"

build_ffmpeg() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"

    log_step "Building FFmpeg"

    # FFmpeg source is in the parent directory of the build script location
    local source_dir="$(cd "$SCRIPT_DIR/../.." && pwd)"
    local build_marker=$(get_build_marker "$ffmpeg_build" "$LIB_NAME")

    # Check dependencies
    if ! check_dependencies "$LIB_NAME" "$ffmpeg_build"; then
        log_error "FFmpeg dependencies not met"
        return 1
    fi

    # Check if rebuild is needed
    if ! is_force_rebuild && ! needs_rebuild "$LIB_NAME" "$source_dir" "$build_marker"; then
        log_info "FFmpeg is up to date, skipping"
        return 0
    fi

    # Build
    cd "$source_dir"

    # Find Vulkan headers path (required for libplacebo)
    local vulkan_include=""
    if [ -d "/opt/homebrew/include/vulkan" ]; then
        vulkan_include="-I/opt/homebrew/include"
    elif [ -d "/opt/homebrew/Cellar/vulkan-headers" ]; then
        local vulkan_header_dir=$(find /opt/homebrew/Cellar/vulkan-headers -type d -name "include" | head -1)
        if [ -n "$vulkan_header_dir" ]; then
            vulkan_include="-I$(dirname "$vulkan_header_dir")"
        fi
    fi

    log_info "Configuring FFmpeg..."
    PKG_CONFIG_PATH="$ffmpeg_build/lib/pkgconfig" ./configure \
        --prefix="$ffmpeg_build" \
        --extra-cflags="-I$ffmpeg_build/include $vulkan_include" \
        --extra-ldflags="-L$ffmpeg_build/lib" \
        --extra-libs="-lpthread -lm" \
        --bindir="$ffmpeg_build/bin" \
        --enable-shared \
        --enable-gpl \
        --enable-libfdk_aac \
        --enable-libfreetype \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libaom \
        --enable-libopenh264 \
        --enable-libkvazaar \
        --enable-libsvtav1 \
        --enable-libdav1d \
        --enable-libplacebo \
        --enable-nonfree \
        --enable-version3

    log_info "Compiling FFmpeg..."
    run_make

    log_info "Installing FFmpeg..."
    make install

    # Mark as built
    mark_built "$LIB_NAME" "$build_marker" "$(git describe --tags --always 2>/dev/null || echo 'unknown')"
    log_success "FFmpeg build completed"

    return 0
}

# If script is run directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <ffmpeg_sources> <ffmpeg_build>"
        exit 1
    fi
    build_ffmpeg "$1" "$2"
fi
