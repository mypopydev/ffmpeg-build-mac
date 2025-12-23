# FFmpeg Mac 构建指南

详细的技术文档，说明如何在 macOS 上构建 FFmpeg 及其依赖库。

> 💡 **快速开始**: 大多数用户只需参考 [README.md](README.md)。本文档面向需要了解技术细节或自定义构建的用户。

## 目录

- [系统要求](#系统要求)
- [构建架构](#构建架构)
- [使用构建脚本](#使用构建脚本)
- [手动构建](#手动构建)
- [环境配置](#环境配置)
- [自定义配置](#自定义配置)
- [故障排除](#故障排除)

## 系统要求

### 操作系统
- macOS 10.15+ (Catalina 或更高)
- 推荐使用最新版 macOS

### 必需工具

通过 Homebrew 安装：
```bash
# 安装 Homebrew（如未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 Xcode Command Line Tools
xcode-select --install

# 构建脚本会自动安装其他依赖
```

## 构建架构

### 动态链接架构

本构建系统使用**动态链接**（shared libraries），所有库编译为 `.dylib` 格式：

```
优势：
✅ 减少可执行文件大小
✅ 库可独立更新
✅ 内存共享，节省资源

注意：
⚠️  需要设置 DYLD_LIBRARY_PATH
⚠️  运行时需要 .dylib 文件
```

### 目录结构

```
ffmpeg-build-mac/
├── ffmpeg_sources/      # 所有源代码
│   ├── x264/
│   ├── x265_git/
│   ├── ffmpeg/
│   └── ...
└── ffmpeg_build/        # 统一安装目录
    ├── bin/            # 可执行文件
    ├── lib/            # 动态库 (.dylib)
    ├── include/        # 头文件
    └── .build_markers/ # 增量构建状态
```

## 使用构建脚本

### 基本用法

```bash
# 完整构建（推荐）
./build_mac.sh

# 查看所有选项
./build_mac.sh --help
```

### 常用场景

```bash
# 快速并行构建
./build_mac.sh -j 8

# 只构建特定库
./build_mac.sh -l x264 -l ffmpeg

# Debug 版本（包含调试符号）
./build_mac.sh -d

# 强制重新编译
./build_mac.sh -f

# 清理并重建
./build_mac.sh -c build -f
```

## 手动构建

### 1. 准备环境

```bash
# 创建目录
mkdir -p ffmpeg_sources ffmpeg_build/{bin,lib,include}

# 设置环境变量
export FFMPEG_BUILD="$(pwd)/ffmpeg_build"
export PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig"
```

### 2. 编译库

参考 `scripts/libs/build_*.sh` 中的编译步骤，例如：

```bash
# x264
cd ffmpeg_sources
git clone https://code.videolan.org/videolan/x264.git
cd x264
./configure --prefix="$FFMPEG_BUILD" --enable-shared --enable-pic
make -j$(sysctl -n hw.ncpu)
make install
```

### 3. 编译 FFmpeg

```bash
cd ffmpeg_sources/ffmpeg
PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig" ./configure \
    --prefix="$FFMPEG_BUILD" \
    --bindir="$FFMPEG_BUILD/bin" \
    --enable-shared \
    --enable-gpl \
    --enable-nonfree \
    --enable-version3 \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libfdk-aac \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvpx \
    --enable-libaom \
    --enable-libopenh264 \
    --enable-libkvazaar \
    --enable-libsvtav1 \
    --enable-libdav1d \
    --enable-libplacebo

make -j$(sysctl -n hw.ncpu)
make install
```

## 环境配置

### 临时设置（推荐用于测试）

```bash
export PATH="$(pwd)/ffmpeg_build/bin:$PATH"
export DYLD_LIBRARY_PATH="$(pwd)/ffmpeg_build/lib:$DYLD_LIBRARY_PATH"
```

### 永久设置

使用提供的环境脚本：
```bash
# 临时设置
source ./env_setup.sh -t

# 永久设置（写入 ~/.zshrc）
source ./env_setup.sh -p
```

### 验证配置

```bash
# 检查 FFmpeg 版本
ffmpeg -version

# 检查动态库依赖
otool -L $(which ffmpeg)

# 验证编码器可用性
ffmpeg -encoders | grep -E "264|265|aac|opus"
```

## 自定义配置

### 1. 启用/禁用库 (推荐)

使用 `config/build_options.conf` 控制要构建的库：

```bash
# 编辑配置文件
vim config/build_options.conf

# 示例：只构建核心视频编码器
ENABLED_LIBRARIES=(
    "x264"
    "x265"
    "libvpx"
    "ffmpeg"
)
```

脚本会自动生成对应的 `./configure` 参数（如 `--enable-libx264`）。

### 2. 添加 FFmpeg 编译选项

同样在 `config/build_options.conf` 中配置：

```bash
# 添加额外的 configure 标志
EXTRA_FFMPEG_FLAGS="--enable-libfreetype --disable-network"
```

### 3. 修改库的编译选项 (高级)

如果需要修改某个依赖库（如 x264）的具体编译参数，则需要编辑对应的脚本 `scripts/libs/build_<libname>.sh`：

```bash
# 示例：修改 x264 配置
vim scripts/libs/build_x264.sh

# 在 configure 命令中添加/删除选项
./configure \
    --prefix="$ffmpeg_build" \
    --enable-shared \
    --enable-pic \
    --bit-depth=10  # 添加 10-bit 支持
```

### 4. 版本控制

编辑 `config/versions.conf`：

```bash
# 使用稳定版
BUILD_MODE="stable"
X264_VERSION="stable"
X265_VERSION="3.5"
FFMPEG_VERSION="n6.0"

# 或使用特定 commit
X264_VERSION="a8b68ebfaa68621b5ac8907610d3335971839d52"
```

## 故障排除

### 编译错误

| 问题 | 解决方案 |
|------|----------|
| `nasm/yasm not found` | `brew install nasm yasm` |
| `pkg-config not found` | `brew install pkg-config` |
| `Library not loaded` | 设置 `DYLD_LIBRARY_PATH` |
| CMake 错误 | `brew install cmake` |

### 详细调试

```bash
# 单线程+详细输出
./build_mac.sh -j 1 -v

# 查看配置日志
cat ffmpeg_sources/ffmpeg/ffbuild/config.log

# 检查库是否正确安装
ls -la ffmpeg_build/lib/*.dylib
pkg-config --list-all | grep -E "264|265|aac"
```

### 运行时问题

```bash
# 检查动态库依赖
otool -L ffmpeg_build/bin/ffmpeg

# 修复库路径（如果需要）
install_name_tool -change \
    old_path \
    new_path \
    ffmpeg_build/bin/ffmpeg

# 验证环境变量
echo $PATH
echo $DYLD_LIBRARY_PATH
```

### 清理和重建

```bash
# 清理构建产物（保留源码）
./build_mac.sh -c build

# 完全清理
./build_mac.sh -c all

# 或手动清理
rm -rf ffmpeg_build ffmpeg_sources
```

## 包含的编码器和库

### 视频编码
- **H.264**: x264 (主要), openh264 (备用)
- **H.265/HEVC**: x265 (主要), kvazaar (备用)
- **VP8/VP9**: libvpx
- **AV1**: libaom (编码), SVT-AV1 (快速编码), dav1d (解码)
- **VVC/H.266**: vvenc (新一代视频编码)
- **图像格式**: libjxl (JPEG XL - 新一代图像格式)

### 音频编码
- **AAC**: fdk-aac (高质量)
- **MP3**: lame
- **Opus**: opus (现代编码)

### 视频处理
- **libplacebo**: GPU 加速的视频处理和色彩管理

### 构建系统类型

| 库 | 构建系统 | 特殊要求 |
|---|---------|---------|
| x264, x265 | Autotools/CMake | - |
| fdk-aac, lame, opus | Autotools | 需要 autogen |
| libvpx, libaom, svtav1 | CMake | install_name_tool 修复 |
| dav1d, libplacebo | Meson | Ninja 构建 |
| openh264 | Make | 直接 make |
| libjxl | CMake | 需要 submodule |
| ffmpeg | Autotools | 复杂配置 |

## 许可证

**重要**: 启用某些库会影响最终二进制文件的许可证：

- `--enable-gpl`: GPL v2+ (x264, x265, kvazaar)
- `--enable-nonfree`: 非自由软件 (fdk-aac)
- `--enable-version3`: GPL v3+ / LGPL v3+

确保你了解并接受相关许可证条款。

## 技术参考

- [FFmpeg 官方文档](https://ffmpeg.org/documentation.html)
- [FFmpeg 编译指南](https://trac.ffmpeg.org/wiki/CompilationGuide)
- [macOS 动态库机制](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/DynamicLibraries/)
- 基于 [CentOS 编译指南](https://trac.ffmpeg.org/wiki/CompilationGuide/Centos) 修改

---

**提示**: 首次构建需要 15-25 分钟，增量构建仅需 5-10 分钟。使用 `-j 8` 可显著加速。
