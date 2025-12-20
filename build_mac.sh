#!/bin/bash

# FFmpeg Mac 构建脚本 v2.0
# 新特性:
#   - 增量构建支持（只重新编译修改过的库）
#   - 版本管理（可选择稳定版或最新版）
#   - 模块化架构（每个库独立构建脚本）
#   - 并行构建支持（加速编译过程）
#   - 灵活的配置选项

set -e

# ============= Initialization =============

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
cd "$SCRIPT_DIR"

# Load modules in order
source "$SCRIPT_DIR/scripts/common.sh"
source "$SCRIPT_DIR/scripts/config.sh"
source "$SCRIPT_DIR/scripts/logging.sh"
source "$SCRIPT_DIR/scripts/args.sh"
source "$SCRIPT_DIR/scripts/parallel_builder.sh"

# ============= Banner Display =============

show_banner() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  FFmpeg Mac 构建脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# ============= Build Summary =============

show_build_summary() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

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
    log_build_success "$minutes" "$seconds"
}

# ============= Build Execution =============

# Execute the actual build process
execute_build() {
    local start_time=$(date +%s)

    log_step "开始构建..."

    if [ ${#SPECIFIC_LIBS[@]} -gt 0 ]; then
        # Build specific libraries
        log_info "构建指定的库: ${SPECIFIC_LIBS[*]}"
        build_specific_libraries "$FFMPEG_SOURCES" "$FFMPEG_BUILD" "${SPECIFIC_LIBS[@]}" || {
            log_error "构建失败"
            log_build_failure
            return 1
        }
    else
        # Build all libraries
        parallel_build_all "$FFMPEG_SOURCES" "$FFMPEG_BUILD" "$PARALLEL_BUILD" || {
            log_error "构建失败"
            log_build_failure
            return 1
        }
    fi

    # Show success summary
    show_build_summary "$start_time"
    return 0
}

# ============= Clean Operation =============

# Perform clean operation based on mode
perform_clean() {
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
    esac
}

# ============= Dependency Check =============

check_system_dependencies() {
    log_step "检查系统依赖..."

    # Check Homebrew
    if ! command_exists brew; then
        log_error "未找到 Homebrew，请先安装 Homebrew"
        echo "安装命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
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
            return 1
        }
    fi

    log_success "所有依赖已满足"
    return 0
}

# ============= Main Entry Point =============

main() {
    # Initialize configuration
    init_config "$SCRIPT_DIR"

    # Parse command line arguments
    if ! parse_arguments "$@"; then
        exit 1
    fi

    # Validate arguments
    if ! validate_arguments; then
        exit 1
    fi

    # Initialize logging
    init_log_file "$SCRIPT_VERSION"
    enable_file_logging

    # Export configuration for child processes
    export_config

    # Show banner
    show_banner

    # Show configuration
    show_config
    echo ""

    # Handle clean mode
    if [ -n "$CLEAN_MODE" ]; then
        perform_clean "$CLEAN_MODE"
        exit 0
    fi

    # Check system dependencies
    if ! check_system_dependencies; then
        exit 1
    fi

    # Create build directories
    setup_build_dirs "$FFMPEG_BUILD" "$FFMPEG_SOURCES"

    # Load version configuration
    load_versions "$SCRIPT_DIR"

    # Execute build
    if ! execute_build; then
        exit 1
    fi
}

# Run main function
main "$@"
