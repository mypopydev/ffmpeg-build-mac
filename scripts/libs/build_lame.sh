#!/bin/bash

# Build script for libmp3lame

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="lame"
# Use GitHub mirror for better reliability
REPO_URL="git@github.com:mypopydev/lame.git"

build_lame() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${LAME_VERSION:-latest}"

    log_step "Building $LIB_NAME (version: $version)"

    local source_dir="$ffmpeg_sources/$LIB_NAME"
    local build_marker=$(get_build_marker "$ffmpeg_build" "$LIB_NAME")

    # Check if rebuild is needed
    if ! is_force_rebuild && ! needs_rebuild "$LIB_NAME" "$source_dir" "$build_marker"; then
        log_info "$LIB_NAME is up to date, skipping"
        return 0
    fi

    # Clone or update from GitHub
    if [ ! -d "$source_dir" ]; then
        log_info "Cloning $LIB_NAME from GitHub..."
        git clone "$REPO_URL" "$source_dir" || {
            log_error "Failed to clone $LIB_NAME"
            return 1
        }
    else
        log_info "Updating $LIB_NAME..."
        cd "$source_dir"
        git pull || log_warning "Failed to update, using existing version"
    fi

    # Build
    cd "$source_dir"

    # Generate configure script if needed
    log_info "Running autoreconf for $LIB_NAME..."
    if [ ! -f "configure" ]; then
        ./autogen.sh || autoreconf -fiv || true
    fi

    log_info "Configuring $LIB_NAME..."
    ./configure --prefix="$ffmpeg_build" \
        --bindir="$ffmpeg_build/bin" \
        --enable-shared \
        --enable-nasm

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
    build_lame "$1" "$2"
fi
