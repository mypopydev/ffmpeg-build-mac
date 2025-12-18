#!/bin/bash

# Parallel build scheduler for FFmpeg dependencies
# Manages parallel compilation based on dependency graph

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Define build groups (libraries that can be built in parallel)
# Group 1: No dependencies - all audio/video codecs without interdependencies
declare -a GROUP_1=(
    "x264"
    "x265"
    "fdk-aac"
    "lame"
    "opus"
    "libvpx"
    "libaom"
    "openh264"
    "kvazaar"
    "svtav1"
    "dav1d"
)

# Group 2: FFmpeg (depends on all libraries in Group 1)
declare -a GROUP_2=(
    "ffmpeg"
)

# Build a single library
build_library() {
    local lib_name="$1"
    local ffmpeg_sources="$2"
    local ffmpeg_build="$3"
    local lib_script="$SCRIPT_DIR/libs/build_${lib_name}.sh"

    if [ -f "$lib_script" ]; then
        log_info "Building $lib_name..."
        source "$lib_script"
        build_${lib_name} "$ffmpeg_sources" "$ffmpeg_build"
        return $?
    else
        log_error "Build script not found: $lib_script"
        return 1
    fi
}

# Build a group of libraries in parallel
build_group_parallel() {
    local group_name="$1"
    shift
    local libs=("$@")
    local ffmpeg_sources="$FFMPEG_SOURCES"
    local ffmpeg_build="$FFMPEG_BUILD"
    local max_parallel="${MAX_PARALLEL_JOBS:-4}"

    log_step "Building $group_name (up to $max_parallel jobs in parallel)"

    local pids=()
    local failed=0
    local active_jobs=0

    for lib in "${libs[@]}"; do
        # Wait if we've reached max parallel jobs
        while [ $active_jobs -ge $max_parallel ]; do
            # Check for completed jobs
            for i in "${!pids[@]}"; do
                local pid="${pids[$i]}"
                if ! kill -0 "$pid" 2>/dev/null; then
                    # Job completed, check exit status
                    wait "$pid"
                    local exit_code=$?
                    if [ $exit_code -ne 0 ]; then
                        log_error "Build failed for job with PID $pid (exit code: $exit_code)"
                        failed=1
                    fi
                    unset 'pids[$i]'
                    active_jobs=$((active_jobs - 1))
                fi
            done
            sleep 0.5
        done

        # Start new job
        (
            build_library "$lib" "$ffmpeg_sources" "$ffmpeg_build" 2>&1 | \
            while IFS= read -r line; do
                echo "[$lib] $line"
            done
        ) &

        local pid=$!
        pids+=("$pid")
        active_jobs=$((active_jobs + 1))
        log_info "Started $lib (PID: $pid, active jobs: $active_jobs)"
    done

    # Wait for all remaining jobs
    for pid in "${pids[@]}"; do
        if [ -n "$pid" ]; then
            wait "$pid"
            local exit_code=$?
            if [ $exit_code -ne 0 ]; then
                log_error "Build failed for job with PID $pid (exit code: $exit_code)"
                failed=1
            fi
        fi
    done

    if [ $failed -ne 0 ]; then
        log_error "$group_name: Some builds failed"
        return 1
    fi

    log_success "$group_name: All builds completed"
    return 0
}

# Build a group of libraries sequentially
build_group_sequential() {
    local group_name="$1"
    shift
    local libs=("$@")
    local ffmpeg_sources="$FFMPEG_SOURCES"
    local ffmpeg_build="$FFMPEG_BUILD"

    log_step "Building $group_name (sequential)"

    for lib in "${libs[@]}"; do
        build_library "$lib" "$ffmpeg_sources" "$ffmpeg_build" || {
            log_error "$group_name: Build failed for $lib"
            return 1
        }
    done

    log_success "$group_name: All builds completed"
    return 0
}

# Main parallel build function
parallel_build_all() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    local parallel_mode="${3:-true}"

    export FFMPEG_SOURCES="$ffmpeg_sources"
    export FFMPEG_BUILD="$ffmpeg_build"

    log_info "Parallel build mode: $parallel_mode"
    log_info "Max parallel jobs: ${MAX_PARALLEL_JOBS:-4}"

    # Build Group 1 (independent libraries)
    if [ "$parallel_mode" = "true" ]; then
        build_group_parallel "Group 1: Independent Libraries" "${GROUP_1[@]}" || return 1
    else
        build_group_sequential "Group 1: Independent Libraries" "${GROUP_1[@]}" || return 1
    fi

    # Build Group 2 (FFmpeg - depends on Group 1)
    # FFmpeg always builds sequentially as it's a single library
    build_group_sequential "Group 2: FFmpeg" "${GROUP_2[@]}" || return 1

    return 0
}

# Build specific libraries
build_specific_libraries() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    shift 2
    local libs=("$@")

    export FFMPEG_SOURCES="$ffmpeg_sources"
    export FFMPEG_BUILD="$ffmpeg_build"

    log_info "Building specific libraries: ${libs[*]}"

    for lib in "${libs[@]}"; do
        build_library "$lib" "$ffmpeg_sources" "$ffmpeg_build" || {
            log_error "Build failed for $lib"
            return 1
        }
    done

    return 0
}

# Export functions
export -f build_library build_group_parallel build_group_sequential
export -f parallel_build_all build_specific_libraries
