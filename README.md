# FFmpeg Mac 构建工具 v2.0

一个用于在 macOS 上自动构建 FFmpeg 开发环境的工具，支持增量构建、并行编译和版本管理。

## 目录

- [快速开始](#快速开始)
- [核心特性](#核心特性)
- [使用指南](#使用指南)
- [包含的库](#包含的库)
- [高级功能](#高级功能)
- [故障排除](#故障排除)

## 快速开始

### 前置要求

- macOS 10.15+
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools: `xcode-select --install`

### 三步构建

```bash
# 1. 克隆并进入目录
git clone <repository-url> && cd ffmpeg-build-mac

# 2. 运行构建（自动安装依赖）
./build_mac.sh

# 3. 设置环境并验证
source ./env_setup.sh -t
ffmpeg -version
```

## 核心特性

| 特性 | 说明 | v1.0 | v2.0 |
|------|------|------|------|
| 🚀 **增量构建** | 只重编译修改过的库 | ❌ | ✅ |
| ⚡ **并行编译** | 多核并行加速 | ❌ | ✅ 最高4倍提速 |
| 📦 **版本管理** | 稳定版/开发版切换 | ❌ | ✅ |
| 🔧 **配置驱动** | 简单配置文件管理库开关 | ❌ | ✅ |
| 🧠 **智能依赖** | 自动解析构建依赖关系 | ❌ | ✅ |
| 🔧 **Debug支持** | 包含调试符号 | ❌ | ✅ 所有13个库 |
| 🧩 **模块化** | 独立库脚本 | ❌ | ✅ |

### 性能对比

| 场景 | v1.0 | v2.0 (j4) | v2.0 (j8) |
|------|------|-----------|-----------|
| 首次构建 | 60分钟 | 25分钟 | 15分钟 |
| 增量构建 | 60分钟 | 5-10分钟 | 3-8分钟 |
| 无变更 | 60分钟 | 10秒 | 10秒 |

## 使用指南

### 基本命令

```bash
# 查看帮助
./build_mac.sh --help

# 默认构建（并行4任务）
./build_mac.sh

# 自定义并行数
./build_mac.sh -j 8

# 只构建特定库（会自动构建其依赖）
./build_mac.sh -l ffmpeg

# 强制重新编译
./build_mac.sh -f

# 清理构建产物
./build_mac.sh -c build
```

### 环境管理

```bash
# 临时设置（当前终端）
source ./env_setup.sh -t

# 永久设置（写入shell配置）
source ./env_setup.sh -p

# 查看当前环境
./env_setup.sh --show
```

### 配置管理

**1. 选择要构建的库**

编辑 `config/build_options.conf` 启用或禁用特定库：

```bash
# 启用库
ENABLED_LIBRARIES=(
    "x264"
    "x265"
    "vvenc"     # VVC/H.266编码器
    # "fdk-aac"  # 注释掉以禁用
    "ffmpeg"
)

# 添加自定义 FFmpeg 标志
EXTRA_FFMPEG_FLAGS="--enable-libfreetype"
```

**2. 切换版本**

编辑 `config/versions.conf` 切换版本：

```bash
# 使用最新开发版（默认）
BUILD_MODE="latest"

# 切换到稳定版
BUILD_MODE="stable"
X264_VERSION="stable"
X265_VERSION="3.5"
VVENC_VERSION="v1.10.0"  # VVC编码器版本
```

## 包含的库

### 视频编码器
- **H.264**: x264, openh264
- **H.265/HEVC**: x265, kvazaar
- **VP8/VP9**: libvpx
- **AV1**: libaom, SVT-AV1, dav1d (解码)
- **VVC/H.266**: vvenc
- **图像格式**: libjxl (JPEG XL)

### 音频编码器
- **AAC**: fdk-aac
- **MP3**: lame
- **Opus**: opus

### 视频处理
- **libplacebo**: GPU加速视频处理

## 高级功能

### Debug构建

```bash
# 构建debug版本
./build_mac.sh -d

# 自定义debug标志
./build_mac.sh -d --debug-flags="-g -O1"

# 使用lldb调试
source ./env_setup.sh -t
lldb ./ffmpeg_build/bin/ffmpeg
```

### 动态库构建

vvenc库支持动态库构建（.dylib），默认同时生成静态和动态库：

```bash
# 查看动态库信息
file ffmpeg_build/lib/libvvenc.dylib

# 检查依赖关系
otool -L ffmpeg_build/lib/libvvenc.dylib

# 使用动态库（环境已自动设置）
source ./env_setup.sh -t
ffmpeg -h encoder=libvvenc
```

### 日志管理

```bash
# 保存日志到文件
./build_mac.sh --log-file=build.log

# 详细输出
./build_mac.sh -v

# 安静模式（仅错误/警告）
./build_mac.sh -q
```

### 项目结构

```
ffmpeg-build-mac/
├── build_mac.sh              # 主构建脚本
├── env_setup.sh              # 环境配置脚本
├── config/
│   └── versions.conf         # 版本管理
├── scripts/
│   ├── common.sh             # 通用函数
│   ├── config.sh             # 配置管理
│   ├── logging.sh            # 日志系统
│   ├── args.sh               # 参数解析
│   ├── parallel_builder.sh   # 并行调度
│   └── libs/                 # 各库构建脚本
├── ffmpeg_sources/           # 源码（构建时创建）
└── ffmpeg_build/             # 编译产物
    ├── .build_markers/       # 增量构建标记
    ├── bin/                  # 可执行文件
    ├── lib/                  # 动态库
    └── include/              # 头文件
```

## 故障排除

### 构建失败

```bash
# 单线程查看详细错误
./build_mac.sh -j 1 -v

# 完全清理后重试
./build_mac.sh -c all -f
```

### 找不到动态库

```bash
# 临时设置环境变量
source ./env_setup.sh -t

# 或手动设置
export DYLD_LIBRARY_PATH="$(pwd)/ffmpeg_build/lib:$DYLD_LIBRARY_PATH"
```

### 增量构建未生效

```bash
# 检查构建标记
ls -la ffmpeg_build/.build_markers/

# 强制重建
./build_mac.sh -f
```

## 常见问题

<details>
<summary><b>v2.0 与 v1.0 的主要区别？</b></summary>

- ✅ 增量构建节省时间
- ✅ 并行编译提升速度
- ✅ 版本管理更灵活
- ✅ 模块化架构易维护
- ✅ Debug支持更完善
</details>

<details>
<summary><b>如何指定特定版本？</b></summary>

编辑 `config/versions.conf` 设置具体版本号或 commit hash：
```bash
X264_VERSION="v0.164.3095"
X265_VERSION="3.5"
FFMPEG_VERSION="n6.0"
```
</details>

<details>
<summary><b>并行构建安全吗？</b></summary>

安全。系统会管理依赖关系，确保库按正确顺序构建。
</details>

<details>
<summary><b>如何添加新的库？</b></summary>

1. 在 `scripts/libs/` 创建 `build_newlib.sh`
2. 在 `scripts/parallel_builder.sh` 中添加到 GROUP_1
3. 在 `config/versions.conf` 中添加版本配置
</details>

<details>
<summary><b>vvenc库支持哪些功能？</b></summary>

- ✅ VVC/H.266编码支持
- ✅ 动态库构建（.dylib）
- ✅ 静态库构建（.a）
- ✅ 版本化符号链接管理
- ✅ 与FFmpeg无缝集成

vvenc是Fraunhofer开发的VVC标准参考实现，支持最新的H.266视频编码标准。
</details>

## 许可证

本工具遵循 FFmpeg 项目许可证。第三方库许可证：

- FFmpeg: LGPL/GPL
- x264, x265: GPL
- fdk-aac: Fraunhofer License (非自由)
- lame: LGPL
- opus, vpx, aom: BSD

## 参考资源

- [FFmpeg 官方文档](https://ffmpeg.org/documentation.html)
- [FFmpeg 编译指南](https://trac.ffmpeg.org/wiki/CompilationGuide)
- [提交Issue](../../issues)

---

**构建时间预估**: 首次 15-25分钟 | 增量 5-10分钟 | 无变更 10秒
