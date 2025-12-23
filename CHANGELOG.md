# 更新日志

本文档记录项目的所有重要变更。

## [2.1.0] - 2025-12-23

### 新增功能
- ✨ **libjxl 支持**：添加 JPEG XL 图像格式支持（编码器和解码器）
- ✨ 新增 `scripts/libs/build_libjxl.sh` 构建脚本
- ✨ 新增 `test_libjxl_integration.sh` 集成测试脚本
- ✨ 更新 `LIBJXL_INTEGRATION_SUMMARY.md` 详细说明文档

### 修复
- 🐛 修复 OpenH264 构建失败问题 (解决 `0rm` / `0sh` 错误)
- 🐛 解决环境变量 `QUIET`/`VERBOSE` 与 OpenH264 Makefile 变量冲突的问题
- 🐛 修复 `scripts/config.sh` 中 `SUPPORTED_LIBS` 数组展开逻辑错误

### 改进
- 🔧 将脚本内部环境变量重命名为 `SCRIPT_QUIET`/`SCRIPT_VERBOSE` 以提高兼容性
- 🔧 更新验证脚本 `validate.sh` 支持 libjxl 仓库检查
- 🔧 更新所有文档以反映新增的 libjxl 支持

## [2.0.0] - 2024-XX-XX

### 新增功能
- ✨ 增量构建支持：智能检测变更，只重新编译修改过的库
- ✨ 版本管理：支持稳定版和开发版切换，通过 `config/versions.conf` 配置
- ✨ 模块化架构：每个库独立构建脚本，易于维护和扩展
- ✨ 并行构建：多核并行编译，大幅提升构建速度
- ✨ 灵活配置：丰富的命令行选项和配置文件
- ✨ 环境管理：`env_setup.sh` 脚本一键设置环境变量
- ✨ 清理功能：支持多种清理模式（all/build/sources）
- ✨ Debug 编译支持：所有库都支持 debug 模式构建
- ✨ **构建日志功能**：自动保存构建日志到文件，支持详细/安静模式

### 改进
- 🔧 使用系统的 nasm 和 yasm，不再单独编译
- 🔧 所有文件统一安装到 `ffmpeg_build/` 目录
- 🔧 添加 libplacebo 支持（GPU 加速视频处理）
- 🔧 lame 使用 GitHub 镜像源，提高可靠性
- 🔧 改进错误处理和日志输出
- 🔧 添加构建状态标记系统

### 修复
- 🐛 修复 libaom 构建时删除必要文件的问题
- 🐛 修复 libplacebo 缺少 git submodule 的问题
- 🐛 修复 FFmpeg 源码目录检测问题
- 🐛 修复 vulkan-headers 路径检测问题

### 文档
- 📚 更新 README.md 反映 v2.0 新功能
- 📚 添加 QUICK_REFERENCE.md 快速参考指南
- 📚 添加 IMPROVEMENTS.md 改进建议文档
- 📚 添加 CHANGELOG.md 更新日志

### 技术细节
- 使用构建标记（`.build_markers/`）跟踪构建状态
- 实现依赖图管理，确保正确的构建顺序
- 支持并行构建调度器，管理多任务编译
- 改进的版本控制系统，支持 Git 标签和 commit hash

## [1.0.0] - 2024-XX-XX

### 初始版本
- 基本的 FFmpeg 构建脚本
- 支持主要编码器：x264, x265, fdk-aac, lame, opus, libvpx, libaom
- 支持动态链接构建
- 非侵入式安装

---

## 版本号规则

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)：
- **主版本号**：不兼容的 API 修改
- **次版本号**：向下兼容的功能性新增
- **修订号**：向下兼容的问题修正

## 变更类型说明

- ✨ 新增功能
- 🔧 改进/优化
- 🐛 修复 Bug
- 📚 文档更新
- ⚠️ 破坏性变更
- 🔒 安全修复

