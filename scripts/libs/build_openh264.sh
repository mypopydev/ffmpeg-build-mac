#!/bin/bash

# Build script for openh264

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="openh264"
REPO_URL="https://github.com/cisco/openh264.git"

build_openh264() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local version="${OPENH264_VERSION:-latest}"

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

    log_info "Compiling $LIB_NAME..."

    # Set debug flags for openh264
    local debug_flags=$(get_debug_flags)
    local release_flags=$(get_release_flags)

    # Openh264 uses a different build system, set flags via environment
    CFLAGS="$debug_flags $release_flags" CXXFLAGS="$debug_flags $release_flags" run_make PREFIX="$ffmpeg_build"

    log_info "Installing $LIB_NAME..."
    make install PREFIX="$ffmpeg_build"

    # Fix install_name for macOS
    # OpenH264 produces libopenh264.X.dylib
    fix_dylib_id "$ffmpeg_build/lib" "libopenh264.*.dylib"

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
    build_openh264 "$1" "$2"
fi
