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
