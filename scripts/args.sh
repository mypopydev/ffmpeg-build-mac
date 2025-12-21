#!/bin/bash

# Argument parsing module for FFmpeg build scripts
# Handles command-line argument parsing and validation

# ============= Help Information =============

show_help() {
    cat << EOF
FFmpeg Mac 构建脚本 v${SCRIPT_VERSION}

用法: $0 [选项]

选项:
    -h, --help              显示帮助信息
    -j, --jobs N            并行任务数 (默认: 4)
    -s, --sequential        顺序构建（禁用并行）
    -f, --force             强制重新编译所有库
    -l, --lib LIB           只构建指定的库（可多次使用）
    -c, --clean [mode]      清理模式: all, build, sources
    -d, --debug             启用debug编译（包含调试符号）
    --debug-flags FLAGS     自定义debug编译标志（默认: "-g -O0"）
    --version MODE          版本模式: stable, latest (默认: 从 config/versions.conf 读取)
    --log-file FILE         指定日志文件路径（默认: build_YYYYMMDD_HHMMSS.log）
    -v, --verbose           详细输出模式
    -q, --quiet             安静模式（只显示错误和警告）

示例:
    $0                      # 默认构建（增量编译，并行4个任务）
    $0 -j 8                 # 使用8个并行任务
    $0 -f                   # 强制重新编译所有库
    $0 -l x264 -l x265      # 只编译 x264 和 x265
    $0 -s                   # 顺序构建
    $0 -c build             # 清理构建产物但保留源码
    $0 --version stable     # 使用稳定版本
    $0 -d                   # debug模式构建（包含调试符号）
    $0 -d -l ffmpeg         # 只构建FFmpeg的debug版本
    $0 --debug-flags="-g -O1" # 自定义debug编译标志
    $0 --log-file build.log # 保存日志到指定文件
    $0 -v                   # 详细输出模式
    $0 -q                   # 安静模式

支持的库:
    x264, x265, fdk-aac, lame, opus, libvpx, libaom,
    openh264, kvazaar, svtav1, dav1d, libplacebo, ffmpeg

EOF
}

# ============= Argument Parsing =============

# Parse all command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -j|--jobs)
                if [ -z "$2" ]; then
                    log_error "-j/--jobs 需要一个参数"
                    return 1
                fi
                MAX_PARALLEL_JOBS="$2"
                if ! validate_parallel_jobs "$MAX_PARALLEL_JOBS"; then
                    return 1
                fi
                shift 2
                ;;
            -s|--sequential)
                PARALLEL_BUILD=false
                shift
                ;;
            -f|--force)
                FORCE_REBUILD=1
                shift
                ;;
            -l|--lib)
                if [ -z "$2" ]; then
                    log_error "-l/--lib 需要一个参数"
                    return 1
                fi
                SPECIFIC_LIBS+=("$2")
                shift 2
                ;;
            -c|--clean)
                # Handle optional argument
                if [[ -n "$2" && "$2" != -* ]]; then
                    CLEAN_MODE="$2"
                    shift 2
                else
                    CLEAN_MODE="all"
                    shift
                fi
                ;;
            --version)
                if [ -z "$2" ]; then
                    log_error "--version 需要一个参数"
                    return 1
                fi
                BUILD_MODE="$2"
                shift 2
                ;;
            -d|--debug)
                DEBUG_ENABLED=1
                shift
                ;;
            --debug-flags)
                if [ -z "$2" ]; then
                    log_error "--debug-flags 需要一个参数"
                    return 1
                fi
                DEBUG_FLAGS="$2"
                shift 2
                ;;
            --debug-flags=*)
                DEBUG_FLAGS="${1#*=}"
                shift
                ;;
            --log-file)
                if [ -z "$2" ]; then
                    log_error "--log-file 需要一个参数"
                    return 1
                fi
                LOG_FILE="$2"
                shift 2
                ;;
            --log-file=*)
                LOG_FILE="${1#*=}"
                shift
                ;;
            -v|--verbose)
                SCRIPT_VERBOSE=1
                LOG_LEVEL="verbose"
                shift
                ;;
            -q|--quiet)
                SCRIPT_QUIET=1
                LOG_LEVEL="quiet"
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                return 1
                ;;
        esac
    done

    return 0
}

# ============= Post-Parse Validation =============

# Validate parsed arguments
validate_arguments() {
    # Validate specific libraries if provided
    if [ ${#SPECIFIC_LIBS[@]} -gt 0 ]; then
        if ! validate_libraries "${SPECIFIC_LIBS[@]}"; then
            return 1
        fi
    fi

    # Validate clean mode if provided
    if [ -n "$CLEAN_MODE" ]; then
        if ! validate_clean_mode "$CLEAN_MODE"; then
            return 1
        fi
    fi

    # Validate conflicting options
    if [ "$VERBOSE" = "1" ] && [ "$QUIET" = "1" ]; then
        log_error "不能同时使用 -v/--verbose 和 -q/--quiet"
        return 1
    fi

    return 0
}

# Export functions
export -f show_help parse_arguments validate_arguments
