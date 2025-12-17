# FFmpeg Mac 构建工具

这是一个用于在 macOS 上构建 FFmpeg 开发环境的自动化脚本工具集。

## 功能特性

- ✅ 自动安装所有必需的依赖
- ✅ 从 Git 仓库获取所有第三方库的最新开发版本
- ✅ 支持多种视频编码器：H.264, H.265, VP8/VP9, AV1
- ✅ 支持多种音频编码器：AAC, MP3, Opus
- ✅ 完全自动化构建流程
- ✅ 非侵入式安装（所有文件安装在项目目录中）

## 快速开始

### 前置要求

1. **macOS** (推荐 macOS 10.15 或更高版本)
2. **Homebrew** - macOS 包管理器
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

### 使用方法

1. **克隆或下载此项目**

2. **进入 FFmpeg 源码目录**

   此脚本需要在 FFmpeg 源码目录中运行。如果你还没有 FFmpeg 源码：

   ```bash
   cd /path/to/ffmpeg-source
   git clone https://git.ffmpeg.org/ffmpeg.git .
   ```

3. **复制构建脚本到 FFmpeg 源码目录**

   ```bash
   cp build_mac.sh /path/to/ffmpeg-source/
   ```

4. **运行构建脚本**

   ```bash
   cd /path/to/ffmpeg-source
   chmod +x build_mac.sh
   ./build_mac.sh
   ```

5. **使用构建的 FFmpeg**

   构建完成后，所有文件都安装在 `ffmpeg_build/` 目录下：
   
   ```bash
   # 添加到 PATH
   export PATH="/path/to/ffmpeg-source/ffmpeg_build/bin:$PATH"
   
   # 验证安装
   ffmpeg -version
   ffprobe -version
   ```

## 项目结构

构建完成后，会在 FFmpeg 源码目录中创建以下目录结构：

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

## 包含的编码器

所有库均使用最新开发版本：

- **视频编码器:**
  - H.264 (libx264, openh264)
  - H.265/HEVC (libx265, Kvazaar)
  - VP8/VP9 (libvpx)
  - AV1 (libaom, SVT-AV1, dav1d)

- **音频编码器:**
  - AAC (libfdk_aac)
  - MP3 (libmp3lame)
  - Opus (libopus)

## 详细文档

请查看 [BUILD_MAC.md](BUILD_MAC.md) 获取详细的构建说明和故障排除指南。

## 许可证

本工具脚本遵循与原 FFmpeg 项目相同的许可证。各第三方库的许可证：

- FFmpeg: LGPL/GPL
- libx264, libx265: GPL
- libfdk_aac: Fraunhofer FDK AAC License (非自由软件)
- libmp3lame: LGPL
- libopus: BSD
- libvpx: BSD
- libaom: BSD

使用 `--enable-nonfree` 和 `--enable-gpl` 选项意味着你接受相应的许可证条款。

## 参考

- [FFmpeg 官方编译指南 (CentOS)](https://trac.ffmpeg.org/wiki/CompilationGuide/Centos)
- [FFmpeg 官方文档](https://ffmpeg.org/documentation.html)
- [Homebrew 官网](https://brew.sh/)
