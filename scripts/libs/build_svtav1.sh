#!/bin/bash

# Build script for SVT-AV1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="svtav1"
REPO_URL="https://gitlab.com/AOMediaCodec/SVT-AV1.git"

build_svtav1() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${SVTAV1_VERSION:-latest}"

    log_step "Building $LIB_NAME (version: $version)"

    local source_dir="$ffmpeg_sources/SVT-AV1"
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
    mkdir -p build
    cd build

    log_info "Configuring $LIB_NAME..."
    cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX="$ffmpeg_build" \
        -DENABLE_SHARED=1 \
        -DCMAKE_BUILD_TYPE=Release \
        ..

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
    build_svtav1 "$1" "$2"
fi
