#!/bin/bash

# Build script for dav1d

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="dav1d"
REPO_URL="https://code.videolan.org/videolan/dav1d.git"

build_dav1d() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${DAV1D_VERSION:-latest}"

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
    rm -rf build

    log_info "Configuring $LIB_NAME with meson..."

    # Set build type based on debug mode
    local build_type="release"
    if is_debug_enabled; then
        build_type="debug"
    fi

    meson setup build \
        --prefix="$ffmpeg_build" \
        --buildtype="$build_type" \
        --default-library=shared

    log_info "Compiling $LIB_NAME..."
    ninja -C build

    log_info "Installing $LIB_NAME..."
    ninja -C build install

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
    build_dav1d "$1" "$2"
fi
