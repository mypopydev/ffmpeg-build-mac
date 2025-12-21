#!/bin/bash

# Parallel build scheduler for FFmpeg dependencies
# Manages parallel compilation based on dependency graph

set -e

# Get the scripts directory (not the project root)
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/common.sh"

# Group 1: No dependencies - all audio/video codecs and processing libraries without interdependencies
# Note: These are now managed via config/build_options.conf and library_info.sh

# Normalize library name (convert hyphens to underscores for script/function names)
normalize_lib_name() {
    echo "$1" | tr '-' '_'
}

# Build a single library
build_library() {
    local lib_name="$1"
    local ffmpeg_sources="$2"
    local ffmpeg_build="$3"
    local normalized_name=$(normalize_lib_name "$lib_name")
    local lib_script="$SCRIPTS_DIR/libs/build_${normalized_name}.sh"

    if [ -f "$lib_script" ]; then
        log_info "Building $lib_name..."
        source "$lib_script"
        build_${normalized_name} "$ffmpeg_sources" "$ffmpeg_build"
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

    if [ ${#libs[@]} -eq 0 ]; then
        log_info "$group_name: No libraries to build"
        return 0
    fi

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

    if [ ${#libs[@]} -eq 0 ]; then
        return 0
    fi

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

    # Determine which libraries to build from ENABLED_LIBRARIES
    # If ENABLED_LIBRARIES is empty, use defaults from library_info.sh
    if [ ${#ENABLED_LIBRARIES[@]} -eq 0 ]; then
        ENABLED_LIBRARIES=($(get_all_libraries) "ffmpeg")
    fi

    local group_1_libs=()
    local build_ffmpeg=false

    for lib in "${ENABLED_LIBRARIES[@]}"; do
        if [ "$lib" = "ffmpeg" ]; then
            build_ffmpeg=true
        else
            group_1_libs+=("$lib")
        fi
    done

    # Build Group 1 (independent libraries)
    if [ "$parallel_mode" = "true" ]; then
        build_group_parallel "Group 1: Independent Libraries" "${group_1_libs[@]}" || return 1
    else
        build_group_sequential "Group 1: Independent Libraries" "${group_1_libs[@]}" || return 1
    fi

    # Build Group 2 (FFmpeg)
    if [ "$build_ffmpeg" = "true" ]; then
        build_group_sequential "Group 2: FFmpeg" "ffmpeg" || return 1
    fi

    return 0
}

# Resolve dependencies for a list of libraries
# Returns a unique list of libraries including dependencies, topologically sorted (simple implementation)
resolve_dependencies() {
    local libs=("$@")
    local resolved_libs=()
    local seen_libs=()
    
    # Simple dependency resolution
    # If ffmpeg is in the list, add all enabled group 1 libs first
    local has_ffmpeg=false
    for lib in "${libs[@]}"; do
        if [ "$lib" = "ffmpeg" ]; then
            has_ffmpeg=true
            break
        fi
    done

    if [ "$has_ffmpeg" = "true" ]; then
        # Add all enabled Group 1 libs
        # We use ENABLED_LIBRARIES (minus ffmpeg) as deps for ffmpeg
        for lib in "${ENABLED_LIBRARIES[@]}"; do
            if [ "$lib" != "ffmpeg" ]; then
                resolved_libs+=("$lib")
            fi
        done
        resolved_libs+=("ffmpeg")
    else
        # No complex dependencies for other libs currently
        resolved_libs=("${libs[@]}")
    fi

    echo "${resolved_libs[@]}"
}

# Build specific libraries
build_specific_libraries() {
    local ffmpeg_sources="$1"
    local ffmpeg_build="$2"
    shift 2
    local libs=("$@")

    export FFMPEG_SOURCES="$ffmpeg_sources"
    export FFMPEG_BUILD="$ffmpeg_build"

    # Resolve dependencies
    # Note: simple resolution: if building ffmpeg, build all enabled deps first
    local libs_to_build=()
    if [[ " ${libs[*]} " =~ " ffmpeg " ]]; then
         # If ffmpeg is requested, we assume we want to build its enabled dependencies too
         # to ensure it links correctly.
         log_info "Resolving dependencies for FFmpeg..."
         
         # Get all enabled non-ffmpeg libs
         for lib in "${ENABLED_LIBRARIES[@]}"; do
             if [ "$lib" != "ffmpeg" ]; then
                 libs_to_build+=("$lib")
             fi
         done
         libs_to_build+=("ffmpeg")
         
         # Filter to keep only what was requested? 
         # No, the goal is "Enhance dependency management". 
         # If I say "build ffmpeg", I expect it to work, so I need deps.
         # But if I say "build x264", I only build x264.
         # The current logic builds ALL enabled libs if ffmpeg is requested.
         # This might be too aggressive if I just want to relink ffmpeg?
         # But "build_mac.sh -l ffmpeg" usually means "I want to rebuild ffmpeg".
         # The incremental build system will skip deps if they are already built.
         # So safe to add them.
    else
        libs_to_build=("${libs[@]}")
    fi

    log_info "Building libraries: ${libs_to_build[*]}"

    # Use sequential build for specific libs to be safe and simple
    for lib in "${libs_to_build[@]}"; do
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
