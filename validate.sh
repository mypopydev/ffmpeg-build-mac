#!/bin/bash

# FFmpeg 构建脚本验证工具
# 用于验证构建脚本的配置和依赖，而不执行实际编译

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="$SCRIPT_DIR/build_mac.sh"

echo -e "${BLUE}=== FFmpeg 构建脚本验证工具 ===${NC}\n"

# 1. 检查构建脚本是否存在
echo -e "${YELLOW}[1/8] 检查构建脚本...${NC}"
if [ ! -f "$BUILD_SCRIPT" ]; then
    echo -e "${RED}✗ 错误: 找不到构建脚本: $BUILD_SCRIPT${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 构建脚本存在${NC}"

# 2. 检查脚本语法
echo -e "${YELLOW}[2/8] 检查脚本语法...${NC}"
if bash -n "$BUILD_SCRIPT" 2>&1; then
    echo -e "${GREEN}✓ 脚本语法正确${NC}"
else
    echo -e "${RED}✗ 脚本语法错误${NC}"
    exit 1
fi

# 3. 检查脚本可执行权限
echo -e "${YELLOW}[3/8] 检查脚本权限...${NC}"
if [ -x "$BUILD_SCRIPT" ]; then
    echo -e "${GREEN}✓ 脚本具有执行权限${NC}"
else
    echo -e "${YELLOW}⚠ 脚本没有执行权限，正在添加...${NC}"
    chmod +x "$BUILD_SCRIPT"
    echo -e "${GREEN}✓ 已添加执行权限${NC}"
fi

# 4. 检查 Homebrew
echo -e "${YELLOW}[4/8] 检查 Homebrew...${NC}"
if command -v brew &> /dev/null; then
    BREW_VERSION=$(brew --version | head -n1)
    echo -e "${GREEN}✓ Homebrew 已安装: $BREW_VERSION${NC}"
else
    echo -e "${RED}✗ 未找到 Homebrew${NC}"
    echo "  安装命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# 5. 检查必需的依赖包
echo -e "${YELLOW}[5/8] 检查必需的依赖包...${NC}"
REQUIRED_PACKAGES=(
    "autoconf"
    "automake"
    "cmake"
    "freetype"
    "git"
    "git-svn"
    "libtool"
    "make"
    "nasm"
    "pkg-config"
    "yasm"
    "zlib"
    "bzip2"
)

MISSING_PACKAGES=()
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $pkg"
    else
        echo -e "  ${RED}✗${NC} $pkg (未安装)"
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ 以下包未安装，构建脚本会自动安装它们:${NC}"
    printf '  %s\n' "${MISSING_PACKAGES[@]}"
else
    echo -e "${GREEN}✓ 所有必需的依赖包已安装${NC}"
fi

# 6. 检查 Git 仓库 URL 是否可访问
echo -e "${YELLOW}[6/8] 检查 Git 仓库可访问性...${NC}"
GIT_REPOS=(
    "https://github.com/netwide-assembler/nasm.git"
    "https://github.com/yasm/yasm.git"
    "https://code.videolan.org/videolan/x264.git"
    "https://bitbucket.org/multicoreware/x265_git"
    "https://github.com/mstorsjo/fdk-aac"
    "https://svn.code.sf.net/p/lame/svn/trunk/lame"
    "https://github.com/xiph/opus.git"
    "https://chromium.googlesource.com/webm/libvpx.git"
    "https://aomedia.googlesource.com/aom"
)

REPO_COUNT=0
for repo in "${GIT_REPOS[@]}"; do
    REPO_COUNT=$((REPO_COUNT + 1))
    if git ls-remote "$repo" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $(basename "$repo")"
    else
        echo -e "  ${YELLOW}⚠${NC} $(basename "$repo") (无法验证，可能需要网络连接)"
    fi
done
echo -e "${GREEN}✓ 已检查 $REPO_COUNT 个 Git 仓库${NC}"

# 7. 检查 FFmpeg 源码目录
echo -e "${YELLOW}[7/8] 检查 FFmpeg 源码目录...${NC}"
FFMPEG_DIR="$SCRIPT_DIR/../FFmpeg"
if [ -d "$FFMPEG_DIR" ] && [ -f "$FFMPEG_DIR/configure" ]; then
    echo -e "${GREEN}✓ FFmpeg 源码目录存在: $FFMPEG_DIR${NC}"
    echo -e "  提示: 构建脚本需要在 FFmpeg 源码目录中运行"
else
    echo -e "${YELLOW}⚠ FFmpeg 源码目录未找到: $FFMPEG_DIR${NC}"
    echo -e "  提示: 需要先克隆 FFmpeg 源码:"
    echo -e "    git clone https://git.ffmpeg.org/ffmpeg.git $FFMPEG_DIR"
fi

# 8. 检查磁盘空间
echo -e "${YELLOW}[8/8] 检查磁盘空间...${NC}"
AVAILABLE_SPACE=$(df -h "$SCRIPT_DIR" | awk 'NR==2 {print $4}')
echo -e "${GREEN}✓ 可用磁盘空间: $AVAILABLE_SPACE${NC}"
echo -e "  提示: 完整构建大约需要 2-5 GB 空间"

# 总结
echo ""
echo -e "${BLUE}=== 验证总结 ===${NC}"
echo -e "${GREEN}✓ 构建脚本语法正确${NC}"
echo -e "${GREEN}✓ 基本依赖检查完成${NC}"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "  1. 确保 FFmpeg 源码目录存在"
echo "  2. 将 build_mac.sh 复制到 FFmpeg 源码目录"
echo "  3. 运行: cd /path/to/ffmpeg-source && ./build_mac.sh"
echo ""
echo -e "${BLUE}注意: 完整构建可能需要 30-60 分钟，取决于网络和 CPU 性能${NC}"

