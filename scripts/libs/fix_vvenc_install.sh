#!/bin/bash

# Fix vvenc install location by copying files from vvenc/install to ffmpeg_build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

fix_vvenc_install() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    
    log_step "Fixing vvenc install location"
    
    # Debug: check if directories exist
    log_info "Checking ffmpeg_sources: $ffmpeg_sources"
    log_info "Checking ffmpeg_build: $ffmpeg_build"
    
    # Use absolute paths from project root
    local project_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
    local vvenc_install_dir="$project_root/$ffmpeg_sources/vvenc/install"
    
    if [ ! -d "$vvenc_install_dir" ]; then
        log_error "vvenc install directory not found: $vvenc_install_dir"
        log_info "Current directory: $(pwd)"
        return 1
    fi
    
    # Get absolute path for ffmpeg_build
    local abs_ffmpeg_build="$project_root/$ffmpeg_build"
    
    if [ ! -d "$abs_ffmpeg_build" ]; then
        log_error "ffmpeg build directory not found: $abs_ffmpeg_build"
        return 1
    fi
    
    # Copy all files from vvenc/install to ffmpeg_build
    log_info "Copying vvenc files from $vvenc_install_dir to $abs_ffmpeg_build"
    
    # Create destination directories if they don't exist
    mkdir -p "$abs_ffmpeg_build/include"
    mkdir -p "$abs_ffmpeg_build/lib"
    mkdir -p "$abs_ffmpeg_build/bin"
    mkdir -p "$abs_ffmpeg_build/lib/cmake"
    mkdir -p "$abs_ffmpeg_build/lib/pkgconfig"
    
    # Copy files
    if [ -d "$vvenc_install_dir/include" ]; then
        cp -R "$vvenc_install_dir/include/"* "$abs_ffmpeg_build/include/" 2>/dev/null || true
    fi
    
    if [ -d "$vvenc_install_dir/lib" ]; then
        cp -R "$vvenc_install_dir/lib/"* "$abs_ffmpeg_build/lib/" 2>/dev/null || true
    fi
    
    if [ -d "$vvenc_install_dir/bin" ]; then
        cp -R "$vvenc_install_dir/bin/"* "$abs_ffmpeg_build/bin/" 2>/dev/null || true
    fi
    
    log_success "vvenc install location fixed"
    return 0
}

# If script is run directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <ffmpeg_sources> <ffmpeg_build>"
        exit 1
    fi
    fix_vvenc_install "$1" "$2"
fi