#!/bin/bash

# Configuration module for FFmpeg build scripts
# Manages build configuration, defaults, and validation

# ============= Default Configuration =============

# Build directories
FFMPEG_SOURCES=""
FFMPEG_BUILD=""
BIN_DIR=""

# Build options
PARALLEL_BUILD=true
MAX_PARALLEL_JOBS=4
FORCE_REBUILD=0
CLEAN_MODE=""
SPECIFIC_LIBS=()

# Debug options
DEBUG_ENABLED=0
DEBUG_FLAGS="-g -O0"

# Logging options (defined here for completeness, but managed by logging.sh)
# LOG_FILE=""
# LOG_LEVEL="normal"
# VERBOSE=0
# QUIET=0

# Version configuration
BUILD_MODE=""
SCRIPT_VERSION="2.0.0"

# ============= Supported Libraries =============

SUPPORTED_LIBS=(
    "x264" "x265" "fdk-aac" "lame" "opus"
    "libvpx" "libaom" "openh264" "kvazaar"
    "svtav1" "dav1d" "libplacebo" "ffmpeg"
)

# ============= Configuration Initialization =============

# Initialize configuration with project paths
init_config() {
    local script_dir="$1"

    # Set default paths
    FFMPEG_SOURCES="$script_dir/ffmpeg_sources"
    FFMPEG_BUILD="$script_dir/ffmpeg_build"
    BIN_DIR="$FFMPEG_BUILD/bin"

    # Get version from VERSION file if it exists
    local version_file="$script_dir/VERSION"
    if [ -f "$version_file" ]; then
        SCRIPT_VERSION=$(cat "$version_file" | tr -d '[:space:]')
    fi
}

# ============= Configuration Validation =============

# Validate library names
validate_libraries() {
    local libs=("$@")

    for lib in "${libs[@]}"; do
        local found=0
        for supported in "${SUPPORTED_LIBS[@]}"; do
            if [ "$lib" = "$supported" ]; then
                found=1
                break
            fi
        done

        if [ $found -eq 0 ]; then
            log_error "不支持的库: $lib"
            log_info "支持的库: ${SUPPORTED_LIBS[*]}"
            return 1
        fi
    done

    return 0
}

# Validate parallel jobs count
validate_parallel_jobs() {
    local jobs="$1"

    if ! [[ "$jobs" =~ ^[0-9]+$ ]] || [ "$jobs" -lt 1 ]; then
        log_error "无效的并行任务数: $jobs"
        log_info "并行任务数必须是大于0的整数"
        return 1
    fi

    return 0
}

# Validate clean mode
validate_clean_mode() {
    local mode="$1"

    case "$mode" in
        all|build|sources)
            return 0
            ;;
        *)
            log_error "未知的清理模式: $mode"
            log_info "支持的模式: all, build, sources"
            return 1
            ;;
    esac
}

# ============= Configuration Export =============

# Export all configuration variables
export_config() {
    # Export directories
    export FFMPEG_SOURCES
    export FFMPEG_BUILD
    export BIN_DIR

    # Export build options
    export PARALLEL_BUILD
    export MAX_PARALLEL_JOBS
    export FORCE_REBUILD
    export BUILD_MODE

    # Export debug options
    export DEBUG_ENABLED
    export DEBUG_FLAGS

    # Export logging options
    export LOG_FILE
    export LOG_LEVEL
    export VERBOSE
    export QUIET
}

# ============= Configuration Display =============

# Show current configuration
show_config() {
    log_info "项目目录: ${SCRIPT_DIR:-$(pwd)}"
    log_info "构建目录: $FFMPEG_BUILD"
    log_info "源码目录: $FFMPEG_SOURCES"

    # Show build mode
    if [ "$DEBUG_ENABLED" = "1" ]; then
        log_info "构建模式: DEBUG (包含调试符号)"
        log_info "Debug标志: $DEBUG_FLAGS"
    else
        log_info "构建模式: RELEASE (优化编译)"
    fi

    # Show parallel build status
    if [ "$PARALLEL_BUILD" = "true" ]; then
        log_info "并行构建: 启用 (最大并行任务: $MAX_PARALLEL_JOBS)"
    else
        log_info "并行构建: 禁用 (顺序构建)"
    fi

    # Show force rebuild status
    if [ "$FORCE_REBUILD" = "1" ]; then
        log_warning "强制重新编译所有库"
    fi

    # Show specific libraries if set
    if [ ${#SPECIFIC_LIBS[@]} -gt 0 ]; then
        log_info "指定的库: ${SPECIFIC_LIBS[*]}"
    fi
}

# Export functions
export -f init_config validate_libraries validate_parallel_jobs validate_clean_mode
export -f export_config show_config
