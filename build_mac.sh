#!/bin/bash

# FFmpeg Mac 构建脚本 v2.0
# 新特性:
#   - 增量构建支持（只重新编译修改过的库）
#   - 版本管理（可选择稳定版或最新版）
#   - 模块化架构（每个库独立构建脚本）
#   - 并行构建支持（加速编译过程）
#   - 灵活的配置选项

set -e

# ============= 初始化 =============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get version from VERSION file if it exists
VERSION_FILE="$SCRIPT_DIR/VERSION"
if [ -f "$VERSION_FILE" ]; then
    SCRIPT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
else
    SCRIPT_VERSION="2.0.0"
fi

cd "$SCRIPT_DIR"

# Load common functions (will be overridden by log functions below if logging is enabled)
source "$SCRIPT_DIR/scripts/common.sh"
source "$SCRIPT_DIR/scripts/parallel_builder.sh"

# ============= 配置 =============
FFMPEG_SOURCES="$SCRIPT_DIR/ffmpeg_sources"
FFMPEG_BUILD="$SCRIPT_DIR/ffmpeg_build"
BIN_DIR="$FFMPEG_BUILD/bin"

# Default options
PARALLEL_BUILD=true
MAX_PARALLEL_JOBS=4
FORCE_REBUILD=0
CLEAN_MODE=""
SPECIFIC_LIBS=()
DEBUG_ENABLED=0
DEBUG_FLAGS="-g -O0"
LOG_FILE=""
LOG_LEVEL="normal"  # quiet, normal, verbose
VERBOSE=0
QUIET=0

# ============= 帮助信息 =============
show_help() {
    cat << EOF
FFmpeg Mac 构建脚本 v2.0

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

# ============= 参数解析 =============
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -j|--jobs)
                MAX_PARALLEL_JOBS="$2"
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
                SPECIFIC_LIBS+=("$2")
                shift 2
                ;;
            -c|--clean)
                CLEAN_MODE="${2:-all}"
                shift
                if [[ "$1" != -* ]] && [[ -n "$1" ]]; then
                    shift
                fi
                ;;
            --version)
                BUILD_MODE="$2"
                shift 2
                ;;
            -d|--debug)
                DEBUG_ENABLED=1
                shift
                ;;
            --debug-flags)
                DEBUG_FLAGS="$2"
                shift 2
                ;;
            --log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                LOG_LEVEL="verbose"
                shift
                ;;
            -q|--quiet)
                QUIET=1
                LOG_LEVEL="quiet"
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============= 日志功能 =============

# Initialize log file
init_log_file() {
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
        echo "版本: $SCRIPT_VERSION"
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "日志文件: $LOG_FILE"
        echo "=========================================="
        echo ""
    } | tee -a "$LOG_FILE" > /dev/null
    
    log_info "日志文件: $LOG_FILE"
}

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
                if [ "$LOG_LEVEL" = "verbose" ] || [ "$VERBOSE" = "1" ]; then
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

# Override log functions to use log_with_file (will be called after init_log_file)
# These functions will use file logging if LOG_FILE is set, otherwise use standard logging
override_log_functions() {
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
    fi
}

# Log verbose messages (always available)
log_verbose() {
    log_with_file "verbose" "$@"
}

# Log command execution
log_command() {
    if [ "$VERBOSE" = "1" ] || [ "$LOG_LEVEL" = "verbose" ]; then
        log_verbose "执行命令: $*"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行: $*" >> "$LOG_FILE"
}

# ============= 清理功能 =============
clean_build() {
    local mode="${1:-all}"

    case "$mode" in
        all)
            log_warning "清理所有构建产物和源码..."
            rm -rf "$FFMPEG_BUILD" "$FFMPEG_SOURCES"
            log_success "清理完成"
            ;;
        build)
            log_warning "清理构建产物..."
            rm -rf "$FFMPEG_BUILD"
            log_success "清理完成"
            ;;
        sources)
            log_warning "清理源码..."
            rm -rf "$FFMPEG_SOURCES"
            log_success "清理完成"
            ;;
        *)
            log_error "未知的清理模式: $mode"
            log_info "支持的模式: all, build, sources"
            exit 1
            ;;
    esac
}

# ============= 依赖检查 =============
check_dependencies() {
    log_step "检查系统依赖..."

    # Check Homebrew
    if ! command_exists brew; then
        log_error "未找到 Homebrew，请先安装 Homebrew"
        echo "安装命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    log_success "Homebrew 已安装"

    # Required packages
    local required_tools=(
        "autoconf" "automake" "cmake" "git" "git-svn"
        "libtool" "make" "meson" "nasm" "ninja"
        "pkg-config" "python3" "vulkan-headers" "yasm"
    )

    log_info "检查必需工具..."
    local missing=()
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool" && ! brew list "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_warning "以下工具未安装: ${missing[*]}"
        log_info "正在安装缺失的依赖..."
        brew install "${missing[@]}" || {
            log_error "依赖安装失败"
            exit 1
        }
    fi

    log_success "所有依赖已满足"
}

# ============= 主构建流程 =============
main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Initialize log file
    init_log_file
    
    # Override log functions to use file logging
    override_log_functions
    
    # Export configuration
    export MAX_PARALLEL_JOBS
    export FORCE_REBUILD
    export DEBUG_ENABLED
    export DEBUG_FLAGS
    export LOG_FILE
    export LOG_LEVEL
    export VERBOSE

    # Show banner
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  FFmpeg Mac 构建脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    log_info "项目目录: $SCRIPT_DIR"
    log_info "构建目录: $FFMPEG_BUILD"
    log_info "源码目录: $FFMPEG_SOURCES"

    # Show debug mode status
    if [ "$DEBUG_ENABLED" = "1" ]; then
        log_info "构建模式: DEBUG (包含调试符号)"
        log_info "Debug标志: $DEBUG_FLAGS"
    else
        log_info "构建模式: RELEASE (优化编译)"
    fi
    echo ""

    # Handle clean mode
    if [ -n "$CLEAN_MODE" ]; then
        clean_build "$CLEAN_MODE"
        exit 0
    fi

    # Check dependencies
    check_dependencies

    # Create build directories
    setup_build_dirs "$FFMPEG_BUILD" "$FFMPEG_SOURCES"

    # Load version configuration
    load_versions "$SCRIPT_DIR"

    # Start build
    local start_time=$(date +%s)

    log_step "开始构建..."
    if [ "$FORCE_REBUILD" = "1" ]; then
        log_warning "强制重新编译所有库"
    fi

    if [ ${#SPECIFIC_LIBS[@]} -gt 0 ]; then
        # Build specific libraries
        log_info "构建指定的库: ${SPECIFIC_LIBS[*]}"
        build_specific_libraries "$FFMPEG_SOURCES" "$FFMPEG_BUILD" "${SPECIFIC_LIBS[@]}" || {
            log_error "构建失败"
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
            exit 1
        }
    else
        # Build all libraries
        if [ "$PARALLEL_BUILD" = "true" ]; then
            log_info "并行构建模式（最大并行任务: $MAX_PARALLEL_JOBS）"
        else
            log_info "顺序构建模式"
        fi

        parallel_build_all "$FFMPEG_SOURCES" "$FFMPEG_BUILD" "$PARALLEL_BUILD" || {
            log_error "构建失败"
            exit 1
        }
    fi

    # Calculate build time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    # Success message
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  构建成功完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    log_success "构建时间: ${minutes}分${seconds}秒"
    echo ""
    log_info "安装位置:"
    echo "  可执行文件: $BIN_DIR"
    echo "  动态库文件: $FFMPEG_BUILD/lib"
    echo "  头文件: $FFMPEG_BUILD/include"
    echo ""
    if [ -n "$LOG_FILE" ]; then
        log_info "构建日志: $LOG_FILE"
        echo ""
    fi
    log_info "环境设置:"
    echo "  运行以下命令或使用 env_setup.sh 脚本:"
    echo "    export PATH=\"$BIN_DIR:\$PATH\""
    echo "    export DYLD_LIBRARY_PATH=\"$FFMPEG_BUILD/lib:\$DYLD_LIBRARY_PATH\""
    echo ""
    log_info "验证安装:"
    echo "  $BIN_DIR/ffmpeg -version"
    echo ""
    
    # Write summary to log file
    {
        echo ""
        echo "=========================================="
        echo "构建完成"
        echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "构建时间: ${minutes}分${seconds}秒"
        echo "状态: 成功"
        echo "=========================================="
    } >> "$LOG_FILE"
}

# Run main function
main "$@"
