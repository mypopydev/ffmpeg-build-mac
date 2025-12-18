# FFmpeg Build v2.0 - 快速参考

## 常用命令

### 构建命令

```bash
# 基本构建（增量+并行）
./build_mac_v2.sh

# 快速构建（8核）
./build_mac_v2.sh -j 8

# 强制完整重新构建
./build_mac_v2.sh --force

# 只构建特定库
./build_mac_v2.sh -l x264 -l ffmpeg

# 顺序构建（调试时有用）
./build_mac_v2.sh --sequential
```

### 清理命令

```bash
# 清理所有（源码+构建）
./build_mac_v2.sh --clean all

# 只清理构建产物
./build_mac_v2.sh --clean build

# 只清理源码
./build_mac_v2.sh --clean sources
```

### 环境设置

```bash
# 查看当前环境
./env_setup.sh --show

# 临时设置（当前会话）
source ./env_setup.sh -t

# 永久设置（写入配置文件）
source ./env_setup.sh -p

# 移除永久设置
./env_setup.sh --uninstall
```

### 验证命令

```bash
# 验证 FFmpeg
ffmpeg -version

# 查看编码器
ffmpeg -encoders | grep -E 'x264|x265|aac|opus'

# 查看解码器
ffmpeg -decoders | grep -E 'h264|hevc|aac'

# 测试编码
ffmpeg -f lavfi -i testsrc=duration=10:size=1280x720 -c:v libx264 test.mp4
```

## 文件位置

```
配置文件:   config/versions.conf
环境脚本:   env_setup.sh
主脚本:     build_mac_v2.sh

库脚本:     scripts/libs/build_*.sh
通用函数:   scripts/common.sh
并行调度:   scripts/parallel_builder.sh

源码目录:   ffmpeg_sources/
构建目录:   ffmpeg_build/
可执行文件: ffmpeg_build/bin/
动态库:     ffmpeg_build/lib/
构建标记:   ffmpeg_build/.build_markers/
```

## 版本管理

### 编辑版本配置

```bash
vim config/versions.conf

# 切换模式
BUILD_MODE="stable"   # 或 "latest"

# 指定版本
X264_VERSION="stable"
X265_VERSION="3.5"
OPUS_VERSION="v1.4"
```

### 常用版本选项

- `"latest"` - 最新开发版（master/main分支）
- `"stable"` - 稳定分支
- `"v1.2.3"` - 特定标签
- `"abc123"` - 特定 commit hash

## 构建选项速查

| 选项 | 简写 | 说明 | 示例 |
|-----|------|------|------|
| --help | -h | 显示帮助 | `./build_mac_v2.sh -h` |
| --jobs N | -j N | 并行任务数 | `./build_mac_v2.sh -j 8` |
| --sequential | -s | 顺序构建 | `./build_mac_v2.sh -s` |
| --force | -f | 强制重建 | `./build_mac_v2.sh -f` |
| --lib LIB | -l LIB | 构建特定库 | `./build_mac_v2.sh -l x264` |
| --clean MODE | -c MODE | 清理 | `./build_mac_v2.sh -c all` |
| --version MODE | | 版本模式 | `./build_mac_v2.sh --version stable` |

## 库列表

### 视频编码器

- `x264` - H.264 编码器
- `x265` - H.265/HEVC 编码器
- `libvpx` - VP8/VP9 编码器
- `libaom` - AV1 编码器
- `svtav1` - SVT-AV1 编码器
- `dav1d` - AV1 解码器
- `openh264` - OpenH264 编码器
- `kvazaar` - Kvazaar HEVC 编码器

### 音频编码器

- `fdk-aac` - AAC 编码器
- `lame` - MP3 编码器
- `opus` - Opus 编码器

### FFmpeg

- `ffmpeg` - FFmpeg 主程序（依赖所有上述库）

## 工作流示例

### 场景1：日常开发

```bash
# 1. 修改某个库的代码
cd ffmpeg_sources/x264
# ... 修改代码 ...

# 2. 增量构建（自动检测变更）
cd ../..
./build_mac_v2.sh

# 3. 测试
source ./env_setup.sh -t
ffmpeg -version
```

### 场景2：切换到稳定版本

```bash
# 1. 配置稳定版本
vim config/versions.conf
# 设置 BUILD_MODE="stable"
# 设置各库的稳定版本

# 2. 强制重新构建
./build_mac_v2.sh --force

# 3. 验证
ffmpeg -version
```

### 场景3：只更新一个库

```bash
# 1. 更新源码
cd ffmpeg_sources/opus
git pull

# 2. 只重新构建这个库
cd ../..
./build_mac_v2.sh -l opus -l ffmpeg --force
```

### 场景4：全新安装

```bash
# 1. 克隆项目
git clone <repo-url>
cd ffmpeg-build-mac

# 2. 构建
./build_mac_v2.sh -j 8

# 3. 永久设置环境
source ./env_setup.sh -p

# 4. 重启终端或重新加载配置
source ~/.zshrc  # 或 ~/.bashrc

# 5. 验证
ffmpeg -version
```

### 场景5：问题排查

```bash
# 1. 清理并重新构建
./build_mac_v2.sh --clean build --force

# 2. 如果还有问题，完全清理
./build_mac_v2.sh --clean all

# 3. 顺序构建（更容易看到错误）
./build_mac_v2.sh -j 1

# 4. 查看构建状态
ls -la ffmpeg_build/.build_markers/
```

## 性能调优

### CPU核心数选择

```bash
# 查看CPU核心数
sysctl -n hw.ncpu

# 推荐配置：
# 4核  -> -j 4
# 8核  -> -j 6 或 -j 8
# 16核 -> -j 12 或 -j 16

# 留一些核心给系统
./build_mac_v2.sh -j $(($(sysctl -n hw.ncpu) - 2))
```

### 磁盘空间

```bash
# 检查磁盘使用
du -sh ffmpeg_sources ffmpeg_build

# 典型大小：
# ffmpeg_sources: ~2-3 GB
# ffmpeg_build:   ~500 MB - 1 GB
```

## 故障排除速查

| 问题 | 解决方案 |
|-----|---------|
| git clone 失败 | 检查网络，使用代理或镜像源 |
| 编译错误 | `./build_mac_v2.sh -j 1 -f` 重新构建 |
| 找不到动态库 | `source ./env_setup.sh -t` |
| ffmpeg 命令不存在 | 检查 PATH: `./env_setup.sh --show` |
| 增量构建未生效 | `ls ffmpeg_build/.build_markers/` 检查标记 |
| 空间不足 | `./build_mac_v2.sh --clean sources` |
| Homebrew 依赖缺失 | `brew install <package>` |

## 环境变量速查

```bash
# 必需的环境变量
export PATH="/path/to/ffmpeg_build/bin:$PATH"
export DYLD_LIBRARY_PATH="/path/to/ffmpeg_build/lib:$DYLD_LIBRARY_PATH"

# 编译时可能需要
export PKG_CONFIG_PATH="/path/to/ffmpeg_build/lib/pkgconfig:$PKG_CONFIG_PATH"
```

## 有用的别名

添加到 `~/.zshrc` 或 `~/.bashrc`：

```bash
# FFmpeg 构建别名
alias ffbuild='./build_mac_v2.sh'
alias ffbuild-fast='./build_mac_v2.sh -j 8'
alias ffbuild-force='./build_mac_v2.sh --force'
alias ffbuild-clean='./build_mac_v2.sh --clean build'
alias ffenv='source ./env_setup.sh -t'
alias ffstatus='./env_setup.sh --show'

# 快速跳转
alias cdff='cd ~/path/to/ffmpeg-build-mac'
```

## 链接

- 完整文档: [README_V2.md](README_V2.md)
- 迁移指南: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- 原版文档: [README.md](README.md)
- 构建详情: [BUILD_MAC.md](BUILD_MAC.md)
- FFmpeg 官方: https://ffmpeg.org/
- 编译指南: https://trac.ffmpeg.org/wiki/CompilationGuide

## 获取帮助

```bash
# 构建脚本帮助
./build_mac_v2.sh --help

# 环境脚本帮助
./env_setup.sh --help

# 验证脚本
./validate.sh
```
