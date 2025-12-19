#!/bin/bash

# Build script for Kvazaar

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="kvazaar"
REPO_URL="https://github.com/ultravideo/kvazaar.git"

build_kvazaar() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${KVAZAAR_VERSION:-latest}"

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

    log_info "Running autogen for $LIB_NAME..."
    ./autogen.sh

    log_info "Configuring $LIB_NAME..."
    local debug_flags=$(get_debug_flags)
    local release_flags=$(get_release_flags)

    ./configure --prefix="$ffmpeg_build" \
        --enable-shared \
        CFLAGS="$debug_flags $release_flags" \
        CXXFLAGS="$debug_flags $release_flags"

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
    build_kvazaar "$1" "$2"
fi
