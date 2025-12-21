#!/bin/bash

# Build script for FFmpeg

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

LIB_NAME="ffmpeg"
REPO_URL="https://git.ffmpeg.org/ffmpeg.git"

build_ffmpeg() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"

    log_step "Building FFmpeg"

    local source_dir="$ffmpeg_sources/$LIB_NAME"
    local build_marker=$(get_build_marker "$ffmpeg_build" "$LIB_NAME")

    # Check if rebuild is needed
    if ! is_force_rebuild && ! needs_rebuild "$LIB_NAME" "$source_dir" "$build_marker"; then
        log_info "FFmpeg is up to date, skipping"
        return 0
    fi

    # Clone or update FFmpeg repository
    git_clone_or_update "$REPO_URL" "$source_dir" "latest" || {
        log_error "Failed to clone/update FFmpeg"
        return 1
    }

    # Build
    cd "$source_dir"

    # Configure search paths (Header/Library)
    local extra_cflags="-I$ffmpeg_build/include $debug_flags $release_flags"
    local extra_ldflags="-L$ffmpeg_build/lib $debug_flags"
    
    # Add Homebrew paths if available
    if command -v brew >/dev/null 2>&1; then
        local brew_prefix=$(brew --prefix)
        extra_cflags="$extra_cflags -I$brew_prefix/include"
        extra_ldflags="$extra_ldflags -L$brew_prefix/lib"
    fi

    # Generate enable flags for libraries
    local lib_flags=""
    # Check if ENABLED_LIBRARIES is defined (from config), otherwise default to all known
    if [ ${#ENABLED_LIBRARIES[@]} -eq 0 ]; then
        log_warning "No libraries enabled in config, using all supported libraries by default"
        ENABLED_LIBRARIES=($(get_all_libraries))
    fi

    for lib in "${ENABLED_LIBRARIES[@]}"; do
        local flag=$(get_lib_config_flag "$lib")
        if [ -n "$flag" ]; then
            lib_flags="$lib_flags $flag"
        fi
    done

    # Add extra flags from config
    if [ -n "$EXTRA_FFMPEG_FLAGS" ]; then
        lib_flags="$lib_flags $EXTRA_FFMPEG_FLAGS"
    fi

    log_info "Configuring FFmpeg..."
    log_info "Enabled libraries: ${ENABLED_LIBRARIES[*]}"

    PKG_CONFIG_PATH="$ffmpeg_build/lib/pkgconfig" ./configure \
        --prefix="$ffmpeg_build" \
        --extra-cflags="$extra_cflags" \
        --extra-ldflags="$extra_ldflags" \
        --extra-libs="-lpthread -lm" \
        --bindir="$ffmpeg_build/bin" \
        --enable-shared \
        --enable-debug \
        --enable-gpl \
        --enable-nonfree \
        --enable-version3 \
        $lib_flags

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
