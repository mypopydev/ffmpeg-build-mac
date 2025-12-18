#!/bin/bash

# FFmpeg Mac 构建脚本
# 参考: https://trac.ffmpeg.org/wiki/CompilationGuide/Centos
# 适配 macOS 版本
#
# 注意: 本脚本使用所有第三方库的最新开发版本（master/main 分支）
# 这确保你能获得最新的功能和修复，但可能包含未完全测试的代码

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录（FFmpeg源码目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 构建目录配置
FFMPEG_SOURCES="$SCRIPT_DIR/ffmpeg_sources"
FFMPEG_BUILD="$SCRIPT_DIR/ffmpeg_build"

echo -e "${GREEN}=== FFmpeg Mac 构建脚本 ===${NC}"
echo "源码目录: $SCRIPT_DIR"
echo "构建目录: $FFMPEG_BUILD"
echo ""

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}错误: 未找到 Homebrew，请先安装 Homebrew${NC}"
    echo "安装命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# 安装依赖
echo -e "${YELLOW}[1/15] 安装依赖包...${NC}"
brew install \
    autoconf \
    automake \
    cmake \
    freetype \
    git \
    libtool \
    make \
    meson \
    nasm \
    ninja \
    pkg-config \
    python3 \
    vulkan-headers \
    yasm \
    zlib \
    bzip2 \
    || echo -e "${YELLOW}某些包可能已安装，继续...${NC}"

# 创建目录
echo -e "${YELLOW}[2/15] 创建构建目录...${NC}"
mkdir -p "$FFMPEG_SOURCES"
mkdir -p "$FFMPEG_BUILD"/{bin,lib,include,share}

# 检查 nasm 和 yasm（使用系统安装的版本）
echo -e "${YELLOW}[3/15] 检查汇编器工具...${NC}"
if ! command -v nasm &> /dev/null; then
    echo -e "${RED}错误: 未找到 nasm，请确保已通过 brew 安装${NC}"
    exit 1
fi
if ! command -v yasm &> /dev/null; then
    echo -e "${RED}错误: 未找到 yasm，请确保已通过 brew 安装${NC}"
    exit 1
fi

echo -e "${GREEN}✓ NASM 版本: $(nasm -v | head -n1)${NC}"
echo -e "${GREEN}✓ NASM 路径: $(command -v nasm)${NC}"
echo -e "${GREEN}✓ Yasm 版本: $(yasm --version | head -n1)${NC}"
echo -e "${GREEN}✓ Yasm 路径: $(command -v yasm)${NC}"

# libx264 (使用最新开发版本)
echo -e "${YELLOW}[4/15] 编译 libx264 (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "x264" ]; then
    git clone https://code.videolan.org/videolan/x264.git
fi
cd x264
git pull || true
PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig" ./configure \
    --prefix="$FFMPEG_BUILD" \
    --enable-shared \
    --enable-pic
make -j$(sysctl -n hw.ncpu)
make install

# libx265 (使用最新开发版本)
echo -e "${YELLOW}[5/15] 编译 libx265 (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "x265_git" ]; then
    git clone https://bitbucket.org/multicoreware/x265_git
fi
cd x265_git
git pull || true
mkdir -p build/macos
cd build/macos
cmake -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$FFMPEG_BUILD" \
    -DENABLE_SHARED:bool=on \
    ../../source
make -j$(sysctl -n hw.ncpu)
make install

# libfdk_aac (使用最新开发版本)
echo -e "${YELLOW}[6/15] 编译 libfdk_aac (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "fdk-aac" ]; then
    git clone https://github.com/mstorsjo/fdk-aac
fi
cd fdk-aac
git pull || true
autoreconf -fiv
./configure --prefix="$FFMPEG_BUILD" --enable-shared
make -j$(sysctl -n hw.ncpu)
make install

# libmp3lame (使用 GitHub 仓库版本)
echo -e "${YELLOW}[7/15] 编译 libmp3lame (GitHub 版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "lame" ]; then
    echo -e "${YELLOW}从 GitHub 仓库克隆 lame...${NC}"
    if ! git clone git@github.com:mypopydev/lame.git lame; then
        echo -e "${RED}错误: git clone 失败${NC}"
        exit 1
    fi
fi
cd lame
git pull || true

# 生成 configure 脚本（如果需要）
if [ ! -f "configure" ]; then
    echo -e "${YELLOW}生成 configure 脚本...${NC}"
    ./autogen.sh || autoreconf -fiv || true
fi

./configure --prefix="$FFMPEG_BUILD" --enable-shared --enable-nasm
make -j$(sysctl -n hw.ncpu)
make install

# libopus (使用最新开发版本)
echo -e "${YELLOW}[8/15] 编译 libopus (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "opus" ]; then
    git clone https://github.com/xiph/opus.git
fi
cd opus
git pull || true
./autogen.sh
./configure --prefix="$FFMPEG_BUILD" --enable-shared
make -j$(sysctl -n hw.ncpu)
make install

# libvpx (使用最新开发版本)
echo -e "${YELLOW}[9/15] 编译 libvpx (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "libvpx" ]; then
    git clone https://chromium.googlesource.com/webm/libvpx.git
fi
cd libvpx
git pull || true
./configure --prefix="$FFMPEG_BUILD" \
    --disable-examples \
    --disable-unit-tests \
    --enable-vp9-highbitdepth \
    --enable-shared \
    --as=yasm
make -j$(sysctl -n hw.ncpu)
make install

# libaom (使用最新开发版本)
echo -e "${YELLOW}[10/15] 编译 libaom (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "aom" ]; then
    git clone https://aomedia.googlesource.com/aom
fi
cd aom
git pull || true
# 恢复 build/cmake 目录（如果被删除）
if [ ! -d "build/cmake" ]; then
    git restore build/ 2>/dev/null || true
fi
# 只清理构建产物，保留 build/cmake 目录
rm -rf build/CMakeCache.txt build/CMakeFiles build/*.dylib build/*.a 2>/dev/null || true
mkdir -p build
cd build
cmake -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$FFMPEG_BUILD" \
    -DENABLE_SHARED=1 \
    -DENABLE_NASM=on \
    -DCMAKE_BUILD_TYPE=Release \
    ..
make -j$(sysctl -n hw.ncpu)
make install

# openh264 (使用最新开发版本)
echo -e "${YELLOW}[11/15] 编译 openh264 (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "openh264" ]; then
    git clone https://github.com/cisco/openh264.git
fi
cd openh264
git pull || true
make -j$(sysctl -n hw.ncpu) PREFIX="$FFMPEG_BUILD"
make install PREFIX="$FFMPEG_BUILD"

# Kvazaar (使用最新开发版本)
echo -e "${YELLOW}[12/15] 编译 Kvazaar (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "kvazaar" ]; then
    git clone https://github.com/ultravideo/kvazaar.git
fi
cd kvazaar
git pull || true
./autogen.sh
./configure --prefix="$FFMPEG_BUILD" --enable-shared
make -j$(sysctl -n hw.ncpu)
make install

# SVT-AV1 (使用最新开发版本)
echo -e "${YELLOW}[13/15] 编译 SVT-AV1 (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "SVT-AV1" ]; then
    git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git
fi
cd SVT-AV1
git pull || true
rm -rf build
mkdir -p build
cd build
cmake -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$FFMPEG_BUILD" \
    -DENABLE_SHARED=1 \
    -DCMAKE_BUILD_TYPE=Release \
    ..
make -j$(sysctl -n hw.ncpu)
make install

# dav1d (使用最新开发版本)
echo -e "${YELLOW}[14/15] 编译 dav1d (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "dav1d" ]; then
    git clone https://code.videolan.org/videolan/dav1d.git
fi
cd dav1d
git pull || true
rm -rf build
meson setup build \
    --prefix="$FFMPEG_BUILD" \
    --buildtype=release \
    --default-library=shared
ninja -C build
ninja -C build install

# libplacebo (使用最新开发版本)
echo -e "${YELLOW}[15/15] 编译 libplacebo (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "libplacebo" ]; then
    git clone https://code.videolan.org/videolan/libplacebo.git
    cd libplacebo
    git submodule update --init
else
    cd libplacebo
    git pull || true
    git submodule update --init || true
fi
rm -rf build
meson setup build \
    --prefix="$FFMPEG_BUILD" \
    --buildtype=release \
    --default-library=shared
ninja -C build
ninja -C build install

# FFmpeg
echo -e "${GREEN}[16/16] 编译 FFmpeg...${NC}"
cd "$SCRIPT_DIR"

# 检查 FFmpeg 源码是否存在
if [ ! -f "configure" ]; then
    echo -e "${YELLOW}FFmpeg configure 脚本不存在，检查是否需要克隆 FFmpeg...${NC}"
    if [ ! -d "ffmpeg" ] && [ ! -d ".git" ]; then
        echo -e "${YELLOW}正在克隆 FFmpeg 源码...${NC}"
        git clone https://git.ffmpeg.org/ffmpeg.git .
    elif [ -d "ffmpeg" ]; then
        echo -e "${YELLOW}使用 ffmpeg 子目录...${NC}"
        cd ffmpeg
    else
        echo -e "${RED}错误: 未找到 FFmpeg 源码，请确保在 FFmpeg 源码目录中运行此脚本${NC}"
        echo "或者手动克隆: git clone https://git.ffmpeg.org/ffmpeg.git"
        exit 1
    fi
fi

# 所有文件安装到 ffmpeg_build 目录（动态链接）：
# - 可执行文件: ffmpeg_build/bin (默认)
# - 库文件: ffmpeg_build/lib (默认)
# - 头文件: ffmpeg_build/include (默认)

# 查找 Vulkan 头文件路径（libplacebo 需要）
VULKAN_INCLUDE=""
if [ -d "/opt/homebrew/include/vulkan" ]; then
    VULKAN_INCLUDE="-I/opt/homebrew/include"
elif [ -d "/opt/homebrew/Cellar/vulkan-headers" ]; then
    VULKAN_HEADER_DIR=$(find /opt/homebrew/Cellar/vulkan-headers -type d -name "include" | head -1)
    if [ -n "$VULKAN_HEADER_DIR" ]; then
        VULKAN_INCLUDE="-I$(dirname "$VULKAN_HEADER_DIR")"
    fi
fi

PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig" ./configure \
    --prefix="$FFMPEG_BUILD" \
    --extra-cflags="-I$FFMPEG_BUILD/include $VULKAN_INCLUDE" \
    --extra-ldflags="-L$FFMPEG_BUILD/lib" \
    --extra-libs="-lpthread -lm" \
    --enable-shared \
    --enable-gpl \
    --enable-libfdk_aac \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libaom \
    --enable-libopenh264 \
    --enable-libkvazaar \
    --enable-libsvtav1 \
    --enable-libdav1d \
    --enable-libplacebo \
    --enable-nonfree \
    --enable-version3

make -j$(sysctl -n hw.ncpu)
make install

hash -r

echo ""
echo -e "${GREEN}=== 构建完成！ ===${NC}"
echo "所有文件已安装（动态链接）:"
echo "  - 可执行文件: $FFMPEG_BUILD/bin"
echo "  - 动态库文件: $FFMPEG_BUILD/lib"
echo "  - 头文件: $FFMPEG_BUILD/include"
echo ""
echo "使用以下命令添加到环境变量:"
echo "  export PATH=\"$FFMPEG_BUILD/bin:\$PATH\""
echo "  export DYLD_LIBRARY_PATH=\"$FFMPEG_BUILD/lib:\$DYLD_LIBRARY_PATH\""
echo ""
echo "验证安装:"
echo "  $FFMPEG_BUILD/bin/ffmpeg -version"
echo "  $FFMPEG_BUILD/bin/ffprobe -version"

