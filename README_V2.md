# FFmpeg Mac 构建工具 v2.0

这是一个用于在 macOS 上构建 FFmpeg 开发环境的自动化脚本工具集。

## 🆕 v2.0 新特性

- ✅ **增量构建** - 智能检测变更，只重新编译修改过的库
- ✅ **版本管理** - 支持稳定版和开发版切换
- ✅ **模块化架构** - 每个库独立构建脚本，易于维护
- ✅ **并行构建** - 多核并行编译，大幅提升构建速度
- ✅ **灵活配置** - 丰富的命令行选项和配置文件
- ✅ **环境管理** - 一键设置环境变量
- ✅ **清理功能** - 支持多种清理模式

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

### 基本用法

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd ffmpeg-build-mac
   ```

2. **运行构建**
   ```bash
   ./build_mac_v2.sh
   ```

3. **设置环境变量**
   ```bash
   source ./env_setup.sh -t    # 临时设置
   # 或
   source ./env_setup.sh -p    # 永久设置
   ```

4. **验证安装**
   ```bash
   ffmpeg -version
   ```

## 项目结构

```
ffmpeg-build-mac/
├── build_mac_v2.sh          # 新版主构建脚本
├── build_mac.sh             # 旧版构建脚本（保留）
├── env_setup.sh             # 环境变量设置脚本
├── validate.sh              # 验证脚本
├── config/                  # 配置文件目录
│   └── versions.conf        # 版本管理配置
├── scripts/                 # 构建脚本目录
│   ├── common.sh            # 通用函数库
│   ├── parallel_builder.sh  # 并行构建调度器
│   └── libs/                # 各库的构建脚本
│       ├── build_x264.sh
│       ├── build_x265.sh
│       ├── build_fdk_aac.sh
│       ├── build_lame.sh
│       ├── build_opus.sh
│       ├── build_libvpx.sh
│       ├── build_libaom.sh
│       ├── build_openh264.sh
│       ├── build_kvazaar.sh
│       ├── build_svtav1.sh
│       ├── build_dav1d.sh
│       └── build_ffmpeg.sh
├── ffmpeg_sources/          # 外部库源代码（构建时创建）
└── ffmpeg_build/            # 编译产物（构建时创建）
    ├── .build_markers/      # 构建状态标记（增量构建）
    ├── bin/                 # 可执行文件
    ├── lib/                 # 动态库
    ├── include/             # 头文件
    └── share/               # 其他文件
```

## 使用指南

### 构建选项

```bash
# 显示帮助
./build_mac_v2.sh --help

# 并行构建（默认4个任务）
./build_mac_v2.sh

# 自定义并行任务数
./build_mac_v2.sh -j 8

# 顺序构建
./build_mac_v2.sh --sequential

# 强制重新编译所有库
./build_mac_v2.sh --force

# 只构建特定的库
./build_mac_v2.sh --lib x264 --lib x265

# 清理构建产物
./build_mac_v2.sh --clean build

# 清理所有（包括源码）
./build_mac_v2.sh --clean all
```

### 版本管理

编辑 `config/versions.conf` 文件来控制各库的版本：

```bash
# 使用最新开发版（默认）
BUILD_MODE="latest"

# 切换到稳定版
BUILD_MODE="stable"
X264_VERSION="stable"
X265_VERSION="3.5"
# ... 其他库的版本
```

或者通过命令行指定：

```bash
./build_mac_v2.sh --version stable
```

### 增量构建

v2.0 版本支持智能增量构建：

- 首次运行会编译所有库
- 后续运行只会重新编译：
  - 源代码有变更的库
  - 依赖项被重新编译的库
- 使用 `--force` 强制重新编译所有库

### 环境设置

使用 `env_setup.sh` 脚本管理环境变量：

```bash
# 查看当前环境
./env_setup.sh --show

# 临时设置（当前终端会话）
source ./env_setup.sh --temporary

# 永久设置（添加到 shell 配置文件）
source ./env_setup.sh --permanent

# 移除永久设置
./env_setup.sh --uninstall
```

### 单独构建某个库

每个库都有独立的构建脚本，可以单独运行：

```bash
# 单独构建 x264
./scripts/libs/build_x264.sh ./ffmpeg_sources ./ffmpeg_build

# 或使用主脚本
./build_mac_v2.sh --lib x264
```

## 包含的编码器

- **视频编码器:**
  - H.264 (libx264, openh264)
  - H.265/HEVC (libx265, Kvazaar)
  - VP8/VP9 (libvpx)
  - AV1 (libaom, SVT-AV1, dav1d)

- **音频编码器:**
  - AAC (libfdk_aac)
  - MP3 (libmp3lame)
  - Opus (libopus)

## 高级用法

### 自定义配置

编辑各库的构建脚本来自定义编译选项：

```bash
# 修改 x264 的配置选项
vim scripts/libs/build_x264.sh
```

### 添加新的编码器

1. 在 `scripts/libs/` 中创建新的构建脚本
2. 在 `scripts/parallel_builder.sh` 中添加到构建组
3. 在 `config/versions.conf` 中添加版本配置

### 调试构建问题

```bash
# 启用详细输出
set -x
./build_mac_v2.sh

# 查看构建状态
ls -la ffmpeg_build/.build_markers/

# 清理并重试
./build_mac_v2.sh --clean build --force
```

## 性能对比

| 构建模式 | 首次构建 | 增量构建 | 无变更 |
|---------|---------|---------|--------|
| v1.0 顺序 | ~60分钟 | ~60分钟 | ~60分钟 |
| v2.0 顺序 | ~60分钟 | ~5-15分钟 | ~10秒 |
| v2.0 并行(j4) | ~25分钟 | ~5-10分钟 | ~10秒 |
| v2.0 并行(j8) | ~15分钟 | ~3-8分钟 | ~10秒 |

*性能数据因硬件配置和网络速度而异*

## 从 v1.0 迁移

如果你已经使用旧版 `build_mac.sh`：

1. 保留现有的构建目录
2. 直接使用新版脚本：
   ```bash
   ./build_mac_v2.sh
   ```
3. v2.0 会检测已构建的库，跳过不必要的重新编译

## 故障排除

### 问题：构建失败

**解决方案：**
```bash
# 查看详细错误信息
./build_mac_v2.sh -j 1  # 单线程更容易看到错误

# 清理并重试
./build_mac_v2.sh --clean build --force
```

### 问题：增量构建未生效

**解决方案：**
```bash
# 检查构建标记
ls -la ffmpeg_build/.build_markers/

# 强制重新构建
./build_mac_v2.sh --force
```

### 问题：环境变量未生效

**解决方案：**
```bash
# 检查当前环境
./env_setup.sh --show

# 重新设置
source ./env_setup.sh -t
```

### 问题：运行时找不到动态库

**解决方案：**
```bash
# 设置动态库路径
export DYLD_LIBRARY_PATH="$(pwd)/ffmpeg_build/lib:$DYLD_LIBRARY_PATH"

# 或使用环境设置脚本
source ./env_setup.sh -t
```

## 常见问题

**Q: v2.0 和 v1.0 有什么区别？**

A: v2.0 主要改进：
- 增量构建（节省大量时间）
- 并行编译（更快）
- 版本管理（可控的版本）
- 模块化架构（易维护）
- 更好的用户体验

**Q: 可以同时使用 v1.0 和 v2.0 吗？**

A: 可以，它们共享相同的构建目录结构，互相兼容。

**Q: 如何回到特定版本的库？**

A: 编辑 `config/versions.conf`，指定具体的版本号或 commit hash。

**Q: 并行构建安全吗？**

A: 是的。我们仔细管理了依赖关系，确保有依赖的库按正确顺序构建。

**Q: 增量构建如何判断是否需要重新编译？**

A: 通过比较源文件修改时间和构建标记时间。如果有疑问，使用 `--force` 强制重新编译。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

本工具脚本遵循与原 FFmpeg 项目相同的许可证。各第三方库的许可证：

- FFmpeg: LGPL/GPL
- libx264, libx265: GPL
- libfdk_aac: Fraunhofer FDK AAC License (非自由软件)
- libmp3lame: LGPL
- libopus, libvpx, libaom: BSD

使用 `--enable-nonfree` 和 `--enable-gpl` 选项意味着你接受相应的许可证条款。

## 参考

- [FFmpeg 官方编译指南](https://trac.ffmpeg.org/wiki/CompilationGuide)
- [FFmpeg 官方文档](https://ffmpeg.org/documentation.html)
- [原版 README](README.md)
- [详细构建说明](BUILD_MAC.md)
