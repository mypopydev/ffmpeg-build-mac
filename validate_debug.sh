#!/bin/bash

# FFmpeg Debug构建验证工具
# 用于验证debug构建是否包含调试符号，便于调试

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFMPEG_BUILD="$SCRIPT_DIR/ffmpeg_build"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查文件是否包含调试符号
check_debug_symbols() {
    local file_path="$1"
    local file_name="$(basename "$file_path")"

    if [ ! -f "$file_path" ]; then
        log_error "文件不存在: $file_path"
        return 1
    fi

    echo -e "${CYAN}=== 检查: $file_name ===${NC}"

    # 检查文件类型
    local file_info=$(file "$file_path")
    echo "文件类型: $file_info"

    # 检查是否包含调试符号
    if echo "$file_info" | grep -q "debug"; then
        echo -e "${GREEN}✓ 包含调试符号${NC}"
    else
        echo -e "${YELLOW}⚠ 不包含调试符号${NC}"
    fi

    # 检查文件大小（debug版本通常更大）
    local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
    local size_mb=$(echo "scale=2; $file_size / 1024 / 1024" | bc)
    echo "文件大小: ${size_mb}MB"

    # 检查是否可以调试
    if command -v lldb &> /dev/null; then
        if lldb "$file_path" --batch -o "image list" &>/dev/null; then
            echo -e "${GREEN}✓ 可调试 (lldb)${NC}"
        else
            echo -e "${YELLOW}⚠ 不可调试 (lldb)${NC}"
        fi
    fi

    if command -v gdb &> /dev/null; then
        if gdb "$file_path" --batch -ex "quit" &>/dev/null; then
            echo -e "${GREEN}✓ 可调试 (gdb)${NC}"
        else
            echo -e "${YELLOW}⚠ 不可调试 (gdb)${NC}"
        fi
    fi

    echo ""
}

# 检查构建标记中的debug信息
check_build_markers() {
    local markers_dir="$FFMPEG_BUILD/.build_markers"

    if [ ! -d "$markers_dir" ]; then
        log_warning "构建标记目录不存在: $markers_dir"
        return 1
    fi

    echo -e "${CYAN}=== 构建标记信息 ===${NC}"

    for marker in "$markers_dir"/*.marker; do
        if [ -f "$marker" ]; then
            local lib_name=$(basename "$marker" .marker)
            echo -e "\n${MAGENTA}库: $lib_name${NC}"

            # 读取debug信息
            local debug_mode=$(grep "^Debug:" "$marker" 2>/dev/null | cut -d' ' -f2)
            local debug_flags=$(grep "^Debug flags:" "$marker" 2>/dev/null | cut -d' ' -f3-)

            if [ -n "$debug_mode" ]; then
                if [ "$debug_mode" = "1" ]; then
                    echo -e "${GREEN}构建模式: DEBUG${NC}"
                else
                    echo "构建模式: RELEASE"
                fi

                if [ -n "$debug_flags" ]; then
                    echo "Debug标志: $debug_flags"
                fi

                # 显示构建时间
                local build_time=$(grep "^Built on:" "$marker" | cut -d' ' -f3-)
                if [ -n "$build_time" ]; then
                    echo "构建时间: $build_time"
                fi
            else
                echo -e "${YELLOW}⚠ 无debug信息${NC}"
            fi
        fi
    done
}

# 主函数
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  FFmpeg Debug构建验证工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # 检查构建目录是否存在
    if [ ! -d "$FFMPEG_BUILD" ]; then
        log_error "FFmpeg构建目录不存在: $FFMPEG_BUILD"
        log_info "请先运行 ./build_mac.sh 进行构建"
        exit 1
    fi

    log_info "构建目录: $FFMPEG_BUILD"
    echo ""

    # 检查主要二进制文件
    echo -e "${CYAN}=== 检查二进制文件 ===${NC}"
    echo ""

    # 检查FFmpeg可执行文件
    if [ -f "$FFMPEG_BUILD/bin/ffmpeg" ]; then
        check_debug_symbols "$FFMPEG_BUILD/bin/ffmpeg"
    else
        log_warning "FFmpeg可执行文件不存在"
    fi

    if [ -f "$FFMPEG_BUILD/bin/ffprobe" ]; then
        check_debug_symbols "$FFMPEG_BUILD/bin/ffprobe"
    else
        log_warning "ffprobe可执行文件不存在"
    fi

    if [ -f "$FFMPEG_BUILD/bin/ffplay" ]; then
        check_debug_symbols "$FFMPEG_BUILD/bin/ffplay"
    else
        log_warning "ffplay可执行文件不存在"
    fi

    # 检查动态库
    echo -e "${CYAN}=== 检查动态库 ===${NC}"
    echo ""

    local lib_count=0
    for lib in "$FFMPEG_BUILD/lib"/*.dylib; do
        if [ -f "$lib" ] && [ ! -L "$lib" ]; then
            check_debug_symbols "$lib"
            lib_count=$((lib_count + 1))
        fi
    done

    if [ $lib_count -eq 0 ]; then
        log_warning "未找到动态库文件"
    else
        log_info "检查了 $lib_count 个动态库"
    fi

    # 检查构建标记
    check_build_markers

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  验证完成${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    log_info "使用说明:"
    echo "  调试FFmpeg: lldb $FFMPEG_BUILD/bin/ffmpeg"
    echo "  调试库: lldb $FFMPEG_BUILD/lib/libavcodec.dylib"
    echo "  查看符号: nm -g $FFMPEG_BUILD/bin/ffmpeg | grep main"
    echo ""
}

# 显示帮助
show_help() {
    cat << EOF
FFmpeg Debug构建验证工具

用法: $0 [选项]

选项:
    -h, --help    显示帮助信息

功能:
    - 检查二进制文件是否包含调试符号
    - 验证文件是否可调试
    - 显示构建标记中的debug信息
    - 提供调试使用说明

示例:
    $0              # 验证debug构建
    ./build_mac.sh -d   # 构建debug版本
    source env_setup.sh -t  # 设置环境变量

EOF
}

# 参数解析
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac