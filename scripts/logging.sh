#!/bin/bash

# Logging module for FFmpeg build scripts
# Provides centralized logging functionality with file and console output

# ============= Logging Configuration =============

LOG_FILE=""
LOG_LEVEL="normal"  # quiet, normal, verbose
SCRIPT_VERBOSE=0
SCRIPT_QUIET=0

# ============= Logging Initialization =============

# Initialize log file with project info
init_log_file() {
    local script_version="${1:-2.0.0}"

    if [ -z "$LOG_FILE" ]; then
        # Generate default log file name with timestamp
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        LOG_FILE="$SCRIPT_DIR/build_${timestamp}.log"
    fi

    # Convert relative path to absolute path
    if [[ "$LOG_FILE" != /* ]]; then
        LOG_FILE="$SCRIPT_DIR/$LOG_FILE"
    fi

    # Create log directory if needed
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir"

    # Start logging
    {
        echo "=========================================="
        echo "FFmpeg Mac 构建日志"
        echo "版本: $script_version"
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "日志文件: $LOG_FILE"
        echo "=========================================="
        echo ""
    } | tee -a "$LOG_FILE" > /dev/null

    log_info "日志文件: $LOG_FILE"
}

# ============= Core Logging Functions =============

# Enhanced logging function that writes to both terminal and log file
log_with_file() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Determine if we should output based on log level
    local should_output=1
    if [ "$LOG_LEVEL" = "quiet" ] && [ "$level" != "error" ] && [ "$level" != "warning" ]; then
        should_output=0
    fi

    # Output to terminal (with colors) and log file (without colors)
    if [ $should_output -eq 1 ]; then
        case "$level" in
            info)
                echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
                ;;
            success)
                echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
                ;;
            warning)
                echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
                ;;
            error)
                echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
                ;;
            step)
                echo -e "${CYAN}[STEP]${NC} $message" | tee -a "$LOG_FILE"
                ;;
            verbose)
                if [ "$LOG_LEVEL" = "verbose" ] || [ "$SCRIPT_VERBOSE" = "1" ]; then
                    echo -e "${MAGENTA}[VERBOSE]${NC} $message" | tee -a "$LOG_FILE"
                else
                    echo "[VERBOSE] $message" >> "$LOG_FILE"
                fi
                ;;
            *)
                echo "$message" | tee -a "$LOG_FILE"
                ;;
        esac
    else
        # Only write to log file in quiet mode
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Override log functions to use log_with_file when logging is enabled
enable_file_logging() {
    if [ -n "$LOG_FILE" ]; then
        log_info() {
            log_with_file "info" "$@"
        }

        log_success() {
            log_with_file "success" "$@"
        }

        log_warning() {
            log_with_file "warning" "$@"
        }

        log_error() {
            log_with_file "error" "$@"
        }

        log_step() {
            log_with_file "step" "$@"
        }

        # Export overridden functions
        export -f log_info log_success log_warning log_error log_step
    fi
}

# Log verbose messages
log_verbose() {
    log_with_file "verbose" "$@"
}

# Log command execution
log_command() {
    if [ "$SCRIPT_VERBOSE" = "1" ] || [ "$LOG_LEVEL" = "verbose" ]; then
        log_verbose "执行命令: $*"
    fi
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行: $*" >> "$LOG_FILE"
    fi
}

# ============= Build Summary Logging =============

# Write build success summary to log file
log_build_success() {
    local duration_minutes="$1"
    local duration_seconds="$2"

    if [ -n "$LOG_FILE" ]; then
        {
            echo ""
            echo "=========================================="
            echo "构建完成"
            echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "构建时间: ${duration_minutes}分${duration_seconds}秒"
            echo "状态: 成功"
            echo "=========================================="
        } >> "$LOG_FILE"
    fi
}

# Write build failure summary to log file
log_build_failure() {
    if [ -n "$LOG_FILE" ]; then
        {
            echo ""
            echo "=========================================="
            echo "构建失败"
            echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "状态: 失败"
            echo "日志文件: $LOG_FILE"
            echo "=========================================="
        } >> "$LOG_FILE"
    fi
}

# Export functions
export -f init_log_file enable_file_logging
export -f log_with_file log_verbose log_command
export -f log_build_success log_build_failure
