#!/bin/bash

# Build script for libplacebo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="libplacebo"
REPO_URL="https://github.com/haasn/libplacebo.git"

build_libplacebo() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${LIBPLACEBO_VERSION:-latest}"

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

    # Initialize git submodules (required for libplacebo)
    cd "$source_dir"
    log_info "Initializing git submodules for $LIB_NAME..."
    git submodule update --init || {
        log_warning "Failed to update submodules, continuing anyway"
    }

    # Build
    rm -rf build

    log_info "Configuring $LIB_NAME with meson..."
    PKG_CONFIG_PATH="$ffmpeg_build/lib/pkgconfig" meson setup build \
        --prefix="$ffmpeg_build" \
        --buildtype=release \
        --default-library=shared

    log_info "Compiling $LIB_NAME..."
    ninja -C build

    log_info "Installing $LIB_NAME..."
    ninja -C build install

    # Fix dylib install name (libplacebo may use relative paths)
    log_info "Fixing dylib install name for $LIB_NAME..."
    for dylib in "$ffmpeg_build/lib"/libplacebo*.dylib; do
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
    build_libplacebo "$1" "$2"
fi
