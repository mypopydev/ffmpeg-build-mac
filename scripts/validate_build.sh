#!/bin/bash

# Post-build validation script for FFmpeg
# Verifies binary existence, linking integrity, and basic functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/config.sh"

validate_build() {
    local ffmpeg_build="$1"
    local bin_dir="$ffmpeg_build/bin"
    local lib_dir="$ffmpeg_build/lib"

    log_step "Starting Post-Build Validation..."

    # 1. Check Artifact Existence
    log_info "Checking artifacts in $bin_dir..."
    local missing=0
    for binary in ffmpeg ffprobe; do
        if [ ! -x "$bin_dir/$binary" ]; then
            log_error "Missing executable: $binary"
            missing=1
        else
            log_success "Found executable: $binary"
        fi
    done

    if [ $missing -ne 0 ]; then
        log_error "Critical artifacts missing. Validation failed."
        return 1
    fi

    # 2. Check Linking Integrity
    # We want to ensure that the binaries are linking to the libraries in $lib_dir
    # and NOT to system libraries (except for system ones like libSystem, CoreFoundation, etc.)
    log_info "Checking linking integrity..."
    
    local ffmpeg_bin="$bin_dir/ffmpeg"
    local linking_issues=0

    # Get list of linked libraries
    local linked_libs=$(otool -L "$ffmpeg_bin" | tail -n +2 | awk '{print $1}')

    echo "$linked_libs" | while read -r lib; do
        # Ignore system libraries
        if [[ "$lib" == /System/* ]] || [[ "$lib" == /usr/lib/* ]]; then
            continue
        fi

        # Check if library is using @rpath or absolute path to our build dir
        if [[ "$lib" == @rpath/* ]] || [[ "$lib" == "$lib_dir"* ]]; then
            # This is good, but let's verify if it actually resolves
            # For @rpath, we'd need to simulate the loader, but here we just check structure
            :
        elif [[ "$lib" == /usr/local/* ]] || [[ "$lib" == /opt/homebrew/* ]]; then
            log_warning "Potential linkage leak detected: $lib"
            # linking_issues=1 # Make this a warning for now, strict mode could fail
        fi
    done

    # Verify RPATH configuration
    local rpath_check=$(otool -l "$ffmpeg_bin" | grep -A2 LC_RPATH)
    if [[ "$rpath_check" == *"$lib_dir"* ]] || [[ "$rpath_check" == *"@loader_path/../lib"* ]] || [[ "$rpath_check" == *"@executable_path/../lib"* ]]; then
        log_success "RPATH configuration appears correct"
    else
        log_warning "RPATH might be missing or incorrect. Output: $rpath_check"
    fi

    # 3. Functional Test: Version
    log_info "Checking FFmpeg version output..."
    if "$ffmpeg_bin" -version >/dev/null 2>&1; then
        local version_out=$("$ffmpeg_bin" -version | head -n 1)
        log_success "FFmpeg runs successfully: $version_out"
    else
        log_error "FFmpeg failed to run (-version)"
        return 1
    fi

    # 4. Functional Test: Encoding
    log_info "Running basic encoding test..."
    local test_output="$ffmpeg_build/validation_test.mp4"
    rm -f "$test_output"

    # Generate 1 second of test pattern
    if "$ffmpeg_bin" -f lavfi -i testsrc=duration=1:size=320x240:rate=30 -c:v libx264 -preset ultrafast "$test_output" -y >/dev/null 2>&1; then
        if [ -f "$test_output" ] && [ -s "$test_output" ]; then
            log_success "Encoding test passed (generated $test_output)"
            rm -f "$test_output"
        else
            log_error "Encoding test failed: Output file missing or empty"
            return 1
        fi
    else
        log_error "Encoding test command failed"
        # Don't fail the whole build for this if it's just a codec issue, but for now we want robust validation
        return 1
    fi

    log_success "Post-Build Validation Completed Successfully"
    return 0
}

# If script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <ffmpeg_build_dir>"
        exit 1
    fi
    # Use provided build dir, or default relative to script
    BUILD_DIR="$1"
    
    # Initialize config to get logging functions if not already sourced
    if ! type log_info >/dev/null 2>&1; then
        source "$SCRIPT_DIR/common.sh"
    fi
    
    validate_build "$BUILD_DIR"
fi
