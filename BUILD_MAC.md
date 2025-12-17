# FFmpeg Mac 构建指南

本指南基于 [CentOS 编译指南](https://trac.ffmpeg.org/wiki/CompilationGuide/Centos)，适配 macOS 系统。

## 前置要求

1. **macOS** (推荐 macOS 10.15 或更高版本)
2. **Homebrew** - macOS 包管理器
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

## 快速开始

### 方法 1: 使用构建脚本（推荐）

```bash
# 赋予执行权限
chmod +x build_mac.sh

# 运行构建脚本
./build_mac.sh
```

构建脚本会自动：
- 安装所有必需的依赖
- 编译外部库（x264, x265, openh264, Kvazaar, fdk-aac, lame, opus, vpx, aom, SVT-AV1, dav1d）
- 编译 FFmpeg

### 方法 2: 手动构建

如果你想手动控制构建过程，可以按照以下步骤：

#### 1. 安装依赖

```bash
brew install \
    autoconf \
    automake \
    cmake \
    freetype \
    git \
    git-svn \
    libtool \
    make \
    meson \
    nasm \
    ninja \
    pkg-config \
    python3 \
    yasm \
    zlib \
    bzip2
```

#### 2. 创建构建目录

```bash
mkdir -p ffmpeg_sources
mkdir -p ffmpeg_build/{bin,lib,include,share}
```

#### 3. 编译外部库

参考 `build_mac.sh` 脚本中的各个库的编译步骤。

#### 4. 编译 FFmpeg

```bash
PKG_CONFIG_PATH="./ffmpeg_build/lib/pkgconfig" ./configure \
    --prefix="./ffmpeg_build" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I./ffmpeg_build/include" \
    --extra-ldflags="-L./ffmpeg_build/lib" \
    --extra-libs="-lpthread -lm" \
    --bindir="./ffmpeg_build/bin" \
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
    --enable-nonfree \
    --enable-version3

make -j$(sysctl -n hw.ncpu)
make install
```

## 目录结构

构建完成后，会创建以下目录结构：

```
ffmpeg-source/
├── build_mac.sh          # 构建脚本
├── ffmpeg_sources/       # 外部库源代码
│   ├── nasm/             # NASM 源码
│   ├── yasm/             # Yasm 源码
│   ├── x264/             # libx264 源码
│   ├── x265_git/         # libx265 源码
│   ├── fdk-aac/          # libfdk_aac 源码
│   ├── lame/             # libmp3lame 源码
│   ├── opus/             # libopus 源码
│   ├── libvpx/           # libvpx 源码
│   ├── aom/              # libaom 源码
│   ├── openh264/         # openh264 源码
│   ├── kvazaar/          # Kvazaar 源码
│   ├── SVT-AV1/          # SVT-AV1 源码
│   └── dav1d/            # dav1d 源码
└── ffmpeg_build/         # 所有编译后的文件（统一安装目录）
    ├── bin/              # 所有可执行文件
    │   ├── ffmpeg        # FFmpeg 主程序
    │   ├── ffprobe       # FFmpeg 探测工具
    │   ├── ffplay        # FFmpeg 播放器
    │   ├── x264          # x264 编码器
    │   ├── lame          # MP3 编码器
    │   ├── nasm          # NASM 汇编器
    │   └── yasm          # Yasm 汇编器
    ├── lib/              # 所有库文件
    │   ├── *.a           # 静态库文件
    │   └── pkgconfig/    # pkg-config 配置文件
    ├── include/          # 所有头文件
    └── share/            # 其他共享文件
```

**重要说明**：
- 所有编译产物（可执行文件、库文件、头文件）都统一安装到 `ffmpeg_build/` 目录下
- 这种设计便于管理和清理，删除 `ffmpeg_build/` 和 `ffmpeg_sources/` 即可完全清理构建产物
- 不会影响系统目录，完全非侵入式安装

## 使用构建的 FFmpeg

### 添加到 PATH

临时添加（当前终端会话）：
```bash
export PATH="$(pwd)/ffmpeg_build/bin:$PATH"
```

永久添加（推荐）：
```bash
echo 'export PATH="'$(pwd)'/ffmpeg_build/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 验证安装

```bash
./ffmpeg_build/bin/ffmpeg -version
./ffmpeg_build/bin/ffprobe -version
```

## 包含的编码器

构建的 FFmpeg 包含以下编码器（**所有库均使用最新开发版本**）：

- **视频编码器:**
  - H.264 (libx264, openh264) - 从 Git 仓库获取最新开发版本
  - H.265/HEVC (libx265, Kvazaar) - 从 Git 仓库获取最新开发版本
  - VP8/VP9 (libvpx) - 从 Git 仓库获取最新开发版本
  - AV1 (libaom, SVT-AV1) - 从 Git 仓库获取最新开发版本
  - AV1 解码器 (dav1d) - 从 Git 仓库获取最新开发版本

- **音频编码器:**
  - AAC (libfdk_aac) - 从 Git 仓库获取最新开发版本
  - MP3 (libmp3lame) - 从 SVN 仓库通过 git-svn 获取最新开发版本
  - Opus (libopus) - 从 Git 仓库获取最新开发版本

- **汇编器:**
  - NASM - 从 GitHub 获取最新开发版本
  - Yasm - 从 GitHub 获取最新开发版本

**注意:** 使用开发版本意味着你将获得最新的功能和修复，但也可能包含未完全测试的代码。如果遇到问题，可以考虑切换到稳定分支。

## 更新 FFmpeg

### 更新外部库

所有外部库都从 Git 仓库获取，更新非常简单：

```bash
# 更新所有外部库到最新开发版本
cd ffmpeg_sources

# 更新各个库
cd nasm && git pull && cd ..
cd yasm && git pull && cd ..
cd x264 && git pull && cd ..
cd x265_git && git pull && cd ..
cd fdk-aac && git pull && cd ..
cd lame && git svn rebase && cd ..
cd opus && git pull && cd ..
cd libvpx && git pull && cd ..
cd aom && git pull && cd ..
cd openh264 && git pull && cd ..
cd kvazaar && git pull && cd ..
cd SVT-AV1 && git pull && cd ..
cd dav1d && git pull && cd ..
```

然后重新运行 `build_mac.sh` 脚本，它会自动重新编译所有更新的库。

### 更新 FFmpeg

```bash
# 在 FFmpeg 源码目录
git pull
# 重新运行 build_mac.sh 或手动运行 configure, make, make install
```

### 切换到稳定版本

如果你遇到开发版本的问题，可以切换到稳定分支：

```bash
cd ffmpeg_sources/x264
git checkout stable
# 其他库类似，使用 git checkout stable 或 git checkout master
```

## 清理构建

删除构建目录和源代码目录即可完全清理：

```bash
rm -rf ffmpeg_build ffmpeg_sources
```

**注意**：所有编译产物都在 `ffmpeg_build/` 目录下，删除该目录即可清理所有构建文件。

## 故障排除

### 问题: "nasm not found" 或版本过低

**解决方案:**
```bash
brew install nasm
# 或者从源码编译最新版本（见 build_mac.sh）
```

### 问题: "yasm not found"

**解决方案:**
```bash
brew install yasm
```

### 问题: pkg-config 找不到库

**解决方案:**
确保设置了 `PKG_CONFIG_PATH`：
```bash
export PKG_CONFIG_PATH="./ffmpeg_build/lib/pkgconfig:$PKG_CONFIG_PATH"
```

### 问题: 编译 x265 失败

**解决方案:**
x265 在 macOS 上需要使用 `build/macos` 而不是 `build/linux`：
```bash
cd x265_git/build/macos
cmake -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$FFMPEG_BUILD" \
    -DENABLE_SHARED:bool=off \
    ../../source
```

### 问题: 权限错误

**解决方案:**
确保有执行权限：
```bash
chmod +x build_mac.sh
chmod +x configure
```

## 自定义配置

你可以修改 `build_mac.sh` 中的 `./configure` 参数来启用或禁用特定功能：

- 移除不需要的编码器：删除对应的 `--enable-lib*` 选项
- 添加其他库：添加相应的 `--enable-lib*` 选项
- 查看所有选项：`./configure --help`

## 参考

- [FFmpeg 官方编译指南 (CentOS)](https://trac.ffmpeg.org/wiki/CompilationGuide/Centos)
- [FFmpeg 官方文档](https://ffmpeg.org/documentation.html)
- [Homebrew 官网](https://brew.sh/)

## 许可证说明

- FFmpeg: LGPL/GPL
- libx264, libx265, Kvazaar: GPL
- libfdk_aac: Fraunhofer FDK AAC License (非自由软件)
- libmp3lame: LGPL
- libopus: BSD
- libvpx: BSD
- libaom, SVT-AV1, dav1d: BSD
- openh264: BSD

使用 `--enable-nonfree` 和 `--enable-gpl` 选项意味着你接受相应的许可证条款。

