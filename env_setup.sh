#!/bin/bash

# FFmpeg Environment Setup Script
# 自动配置 FFmpeg 环境变量

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFMPEG_BUILD="$SCRIPT_DIR/ffmpeg_build"
BIN_DIR="$FFMPEG_BUILD/bin"
LIB_DIR="$FFMPEG_BUILD/lib"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if build directory exists
if [ ! -d "$FFMPEG_BUILD" ]; then
    echo -e "${RED}错误: FFmpeg 构建目录不存在: $FFMPEG_BUILD${NC}"
    echo "请先运行 build_mac.sh 进行构建"
    exit 1
fi

# Detect shell
detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        echo "unknown"
    fi
}

CURRENT_SHELL=$(detect_shell)

# Get shell config file
get_shell_config() {
    case "$CURRENT_SHELL" in
        zsh)
            echo "$HOME/.zshrc"
            ;;
        bash)
            if [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

SHELL_CONFIG=$(get_shell_config)

# Show help
show_help() {
    cat << EOF
FFmpeg 环境设置脚本

用法:
    source $0 [选项]

选项:
    -h, --help          显示帮助信息
    -t, --temporary     临时设置（仅当前终端会话）
    -p, --permanent     永久设置（添加到 shell 配置文件）
    -s, --show          显示当前设置
    -u, --uninstall     从 shell 配置文件中移除设置

示例:
    source $0 -t        # 临时设置环境变量
    source $0 -p        # 永久设置环境变量
    source $0 -s        # 查看当前设置
    $0 -u               # 移除永久设置

注意: 使用 -t 或 -p 选项时必须用 source 命令执行！

EOF
}

# Show current environment
show_environment() {
    echo -e "${BLUE}=== 当前环境设置 ===${NC}"
    echo ""
    echo "FFmpeg 构建目录: $FFMPEG_BUILD"
    echo ""

    # Check PATH
    if echo "$PATH" | grep -q "$BIN_DIR"; then
        echo -e "${GREEN}✓${NC} PATH 包含 FFmpeg bin 目录"
        echo "  $BIN_DIR"
    else
        echo -e "${RED}✗${NC} PATH 不包含 FFmpeg bin 目录"
    fi

    # Check DYLD_LIBRARY_PATH
    if echo "${DYLD_LIBRARY_PATH:-}" | grep -q "$LIB_DIR"; then
        echo -e "${GREEN}✓${NC} DYLD_LIBRARY_PATH 包含 FFmpeg lib 目录"
        echo "  $LIB_DIR"
    else
        echo -e "${RED}✗${NC} DYLD_LIBRARY_PATH 不包含 FFmpeg lib 目录"
    fi

    echo ""

    # Check if ffmpeg is available
    if command -v ffmpeg &> /dev/null; then
        echo -e "${GREEN}✓${NC} ffmpeg 命令可用"
        echo "  位置: $(which ffmpeg)"
        echo "  版本: $(ffmpeg -version 2>/dev/null | head -n1)"
    else
        echo -e "${RED}✗${NC} ffmpeg 命令不可用"
    fi

    echo ""

    # Check shell config
    if [ -n "$SHELL_CONFIG" ] && [ -f "$SHELL_CONFIG" ]; then
        if grep -q "ffmpeg_build" "$SHELL_CONFIG" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Shell 配置文件包含 FFmpeg 设置"
            echo "  配置文件: $SHELL_CONFIG"
        else
            echo -e "${YELLOW}⚠${NC} Shell 配置文件不包含 FFmpeg 设置"
            echo "  配置文件: $SHELL_CONFIG"
        fi
    fi
}

# Set environment temporarily
set_temporary() {
    echo -e "${BLUE}=== 临时设置环境变量 ===${NC}"

    # Add to PATH if not already present
    if ! echo "$PATH" | grep -q "$BIN_DIR"; then
        export PATH="$BIN_DIR:$PATH"
        echo -e "${GREEN}✓${NC} 已添加到 PATH: $BIN_DIR"
    else
        echo -e "${YELLOW}⚠${NC} PATH 已包含: $BIN_DIR"
    fi

    # Add to DYLD_LIBRARY_PATH if not already present
    if ! echo "${DYLD_LIBRARY_PATH:-}" | grep -q "$LIB_DIR"; then
        export DYLD_LIBRARY_PATH="$LIB_DIR:${DYLD_LIBRARY_PATH:-}"
        echo -e "${GREEN}✓${NC} 已添加到 DYLD_LIBRARY_PATH: $LIB_DIR"
    else
        echo -e "${YELLOW}⚠${NC} DYLD_LIBRARY_PATH 已包含: $LIB_DIR"
    fi

    echo ""
    echo -e "${GREEN}环境变量设置成功！${NC}"
    echo "这些设置仅在当前终端会话中有效"
    echo ""

    # Verify
    if command -v ffmpeg &> /dev/null; then
        echo -e "${GREEN}✓${NC} 验证成功: ffmpeg 命令可用"
        echo "  $(ffmpeg -version 2>/dev/null | head -n1)"
    else
        echo -e "${RED}✗${NC} 验证失败: ffmpeg 命令不可用"
    fi
}

# Set environment permanently
set_permanent() {
    if [ -z "$SHELL_CONFIG" ]; then
        echo -e "${RED}错误: 无法确定 shell 配置文件${NC}"
        exit 1
    fi

    echo -e "${BLUE}=== 永久设置环境变量 ===${NC}"
    echo "配置文件: $SHELL_CONFIG"
    echo ""

    # Check if already configured
    if grep -q "ffmpeg_build" "$SHELL_CONFIG" 2>/dev/null; then
        echo -e "${YELLOW}⚠ 配置文件已包含 FFmpeg 设置${NC}"
        read -p "是否覆盖现有设置？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "已取消"
            exit 0
        fi
        # Remove old settings
        sed -i.bak '/# FFmpeg Environment/,/# End FFmpeg Environment/d' "$SHELL_CONFIG"
    fi

    # Add new settings
    cat >> "$SHELL_CONFIG" << EOF

# FFmpeg Environment - Added by env_setup.sh
export PATH="$BIN_DIR:\$PATH"
export DYLD_LIBRARY_PATH="$LIB_DIR:\$DYLD_LIBRARY_PATH"
# End FFmpeg Environment
EOF

    echo -e "${GREEN}✓${NC} 已添加环境变量到: $SHELL_CONFIG"
    echo ""
    echo -e "${YELLOW}请运行以下命令使设置生效:${NC}"
    echo "  source $SHELL_CONFIG"
    echo ""
    echo "或者重新打开终端窗口"
}

# Uninstall from shell config
uninstall_permanent() {
    if [ -z "$SHELL_CONFIG" ] || [ ! -f "$SHELL_CONFIG" ]; then
        echo -e "${YELLOW}⚠ 配置文件不存在或无法确定${NC}"
        exit 0
    fi

    if ! grep -q "ffmpeg_build" "$SHELL_CONFIG" 2>/dev/null; then
        echo -e "${YELLOW}⚠ 配置文件不包含 FFmpeg 设置${NC}"
        exit 0
    fi

    echo -e "${BLUE}=== 移除永久环境设置 ===${NC}"
    echo "配置文件: $SHELL_CONFIG"
    echo ""

    # Backup and remove
    cp "$SHELL_CONFIG" "$SHELL_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    sed -i.tmp '/# FFmpeg Environment/,/# End FFmpeg Environment/d' "$SHELL_CONFIG"
    rm -f "$SHELL_CONFIG.tmp"

    echo -e "${GREEN}✓${NC} 已从配置文件中移除 FFmpeg 设置"
    echo -e "${GREEN}✓${NC} 备份文件已创建"
    echo ""
    echo -e "${YELLOW}请运行以下命令或重启终端使设置生效:${NC}"
    echo "  source $SHELL_CONFIG"
}

# Main
main() {
    local mode="help"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                return 0
                ;;
            -t|--temporary)
                mode="temporary"
                shift
                ;;
            -p|--permanent)
                mode="permanent"
                shift
                ;;
            -s|--show)
                mode="show"
                shift
                ;;
            -u|--uninstall)
                mode="uninstall"
                shift
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                return 1
                ;;
        esac
    done

    # Execute mode
    case "$mode" in
        temporary)
            set_temporary
            ;;
        permanent)
            set_permanent
            ;;
        show)
            show_environment
            ;;
        uninstall)
            uninstall_permanent
            ;;
        help)
            show_help
            ;;
    esac
}

# Check if script is being sourced or executed
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being executed
    # Only allow certain operations
    case "${1:-}" in
        -u|--uninstall|-s|--show|-h|--help)
            main "$@"
            ;;
        *)
            echo -e "${YELLOW}注意: 要设置环境变量，请使用 source 命令:${NC}"
            echo "  source $0 -t    # 临时设置"
            echo "  source $0 -p    # 永久设置"
            echo ""
            echo "或者查看其他选项:"
            echo "  $0 -h           # 显示帮助"
            echo "  $0 -s           # 显示当前设置"
            echo "  $0 -u           # 移除永久设置"
            ;;
    esac
else
    # Script is being sourced
    main "$@"
fi
