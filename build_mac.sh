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
BIN_DIR="$SCRIPT_DIR/bin"

echo -e "${GREEN}=== FFmpeg Mac 构建脚本 ===${NC}"
echo "源码目录: $SCRIPT_DIR"
echo "构建目录: $FFMPEG_BUILD"
echo "二进制目录: $BIN_DIR"
echo ""

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}错误: 未找到 Homebrew，请先安装 Homebrew${NC}"
    echo "安装命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# 安装依赖
echo -e "${YELLOW}[1/12] 安装依赖包...${NC}"
brew install \
    autoconf \
    automake \
    cmake \
    freetype \
    git \
    git-svn \
    libtool \
    make \
    nasm \
    pkg-config \
    yasm \
    zlib \
    bzip2 \
    || echo -e "${YELLOW}某些包可能已安装，继续...${NC}"

# 创建目录
echo -e "${YELLOW}[2/12] 创建构建目录...${NC}"
mkdir -p "$FFMPEG_SOURCES"
mkdir -p "$FFMPEG_BUILD"
mkdir -p "$BIN_DIR"

# 添加 bin 目录到 PATH
export PATH="$BIN_DIR:$PATH"

# NASM (使用最新开发版本)
echo -e "${YELLOW}[3/12] 编译 NASM (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "nasm" ]; then
    git clone https://github.com/netwide-assembler/nasm.git
fi
cd nasm
git pull || true
./autogen.sh
./configure --prefix="$FFMPEG_BUILD" --bindir="$BIN_DIR"
make -j$(sysctl -n hw.ncpu)
make install

# Yasm (使用最新开发版本)
echo -e "${YELLOW}[4/12] 编译 Yasm (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "yasm" ]; then
    git clone https://github.com/yasm/yasm.git
fi
cd yasm
git pull || true
autoreconf -fiv
./configure --prefix="$FFMPEG_BUILD" --bindir="$BIN_DIR"
make -j$(sysctl -n hw.ncpu)
make install

# libx264 (使用最新开发版本)
echo -e "${YELLOW}[5/12] 编译 libx264 (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "x264" ]; then
    git clone https://code.videolan.org/videolan/x264.git
fi
cd x264
git pull || true
PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig" ./configure \
    --prefix="$FFMPEG_BUILD" \
    --bindir="$BIN_DIR" \
    --enable-static \
    --enable-pic
make -j$(sysctl -n hw.ncpu)
make install

# libx265 (使用最新开发版本)
echo -e "${YELLOW}[6/12] 编译 libx265 (最新开发版本)...${NC}"
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
    -DENABLE_SHARED:bool=off \
    ../../source
make -j$(sysctl -n hw.ncpu)
make install

# libfdk_aac (使用最新开发版本)
echo -e "${YELLOW}[7/12] 编译 libfdk_aac (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "fdk-aac" ]; then
    git clone https://github.com/mstorsjo/fdk-aac
fi
cd fdk-aac
git pull || true
autoreconf -fiv
./configure --prefix="$FFMPEG_BUILD" --disable-shared
make -j$(sysctl -n hw.ncpu)
make install

# libmp3lame (使用最新开发版本，从 SVN 通过 git-svn)
echo -e "${YELLOW}[8/12] 编译 libmp3lame (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "lame" ]; then
    echo "使用 git-svn 从 SVN 仓库克隆 lame..."
    git svn clone https://svn.code.sf.net/p/lame/svn/trunk/lame lame
fi
cd lame
git svn rebase || true
autoreconf -fiv || ./autogen.sh || true
./configure --prefix="$FFMPEG_BUILD" --bindir="$BIN_DIR" --disable-shared --enable-nasm
make -j$(sysctl -n hw.ncpu)
make install

# libopus (使用最新开发版本)
echo -e "${YELLOW}[9/12] 编译 libopus (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "opus" ]; then
    git clone https://github.com/xiph/opus.git
fi
cd opus
git pull || true
./autogen.sh
./configure --prefix="$FFMPEG_BUILD" --disable-shared
make -j$(sysctl -n hw.ncpu)
make install

# libvpx (使用最新开发版本)
echo -e "${YELLOW}[10/12] 编译 libvpx (最新开发版本)...${NC}"
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
    --as=yasm
make -j$(sysctl -n hw.ncpu)
make install

# libaom (使用最新开发版本)
echo -e "${YELLOW}[11/12] 编译 libaom (最新开发版本)...${NC}"
cd "$FFMPEG_SOURCES"
if [ ! -d "aom" ]; then
    git clone https://aomedia.googlesource.com/aom
fi
cd aom
git pull || true
rm -rf build
mkdir -p build
cd build
cmake -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$FFMPEG_BUILD" \
    -DENABLE_SHARED=0 \
    -DENABLE_NASM=on \
    ..
make -j$(sysctl -n hw.ncpu)
make install

# FFmpeg
echo -e "${GREEN}[12/12] 编译 FFmpeg...${NC}"
cd "$SCRIPT_DIR"
PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig" ./configure \
    --prefix="$FFMPEG_BUILD" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I$FFMPEG_BUILD/include" \
    --extra-ldflags="-L$FFMPEG_BUILD/lib" \
    --extra-libs="-lpthread -lm" \
    --bindir="$BIN_DIR" \
    --enable-gpl \
    --enable-libfdk_aac \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libaom \
    --enable-nonfree \
    --enable-version3

make -j$(sysctl -n hw.ncpu)
make install

hash -r

echo ""
echo -e "${GREEN}=== 构建完成！ ===${NC}"
echo "FFmpeg 二进制文件位于: $BIN_DIR"
echo "使用以下命令添加到 PATH:"
echo "  export PATH=\"$BIN_DIR:\$PATH\""
echo ""
echo "验证安装:"
echo "  $BIN_DIR/ffmpeg -version"
echo "  $BIN_DIR/ffprobe -version"

