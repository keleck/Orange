# macOS Universal Binary (Intel + Apple Silicon) 打包指南

本文档说明如何为macOS构建支持Intel和Apple Silicon双架构的Universal Binary应用。

## 功能概述

通过本配置，可以：
- 构建同时支持Intel (x86_64) 和 Apple Silicon (arm64) 的单一应用包
- 使用`lipo`工具自动合并两个架构的二进制文件
- 通过单一命令完成完整的打包过程

## 快速开始

### 方式 1: 使用 Makefile 目标（推荐）

```bash
# 构建通用应用（包含SDK）
make macos_universal

# 仅构建通用核心库（libclash）
make macos_universal_core
```

### 方式 2: 直接使用 Dart 命令

```bash
# 构建通用应用
dart ./setup.dart macos --universal

# 使用缩写
dart ./setup.dart macos -u

# 仅构建核心库
dart ./setup.dart macos --universal --out core
```

## 构建过程详解

该脚本会按以下步骤执行：

1. **构建 ARM64 版本**
   - 编译Apple Silicon架构的core库和应用
   - 产物位置: `libclash/macos/arm64/libclash.dylib`

2. **构建 AMD64/x86_64 版本**
   - 编译Intel架构的core库和应用
   - 产物位置: `libclash/macos/amd64/libclash.dylib`

3. **合并二进制**
   - 使用`lipo -create`命令合并两个架构
   - 输出: `libclash/macos/universal/FlClashCore`

4. **打包分发**
   - 使用flutter_distributor生成DMG格式安装包
   - 最终产物位置: `dist/`

## 输出文件

成功完成后，您将在以下位置找到：

```
dist/
├── mxycloud-universal.dmg          # 通用安装包
├── mxycloud-universal-x64.dmg      # Intel版本（如果单独构建）
└── mxycloud-universal-arm64.dmg    # Apple Silicon版本（如果单独构建）

libclash/macos/
├── arm64/
│   ├── libclash.dylib
│   └── FlClashCore
├── amd64/
│   ├── libclash.dylib
│   └── FlClashCore
└── universal/
    └── FlClashCore                 # 通用二进制
```

## 单架构构建（对比）

如果您只需要单个架构：

```bash
# Intel (x86_64) 版本 - Intel Mac
make macos_amd64

# Apple Silicon (arm64) 版本 - Apple Silicon Mac
make macos_arm64

# 或使用Dart命令
dart ./setup.dart macos --arch amd64
dart ./setup.dart macos --arch arm64
```

## 系统要求

- macOS 10.15 或更高
- Xcode 12+（含lipo工具）
- Flutter SDK
- Dart SDK
- Node.js（用于appdmg）
- Go 1.13+ （用于编译core）

### 依赖安装

```bash
# 如果缺少appdmg
npm install -g appdmg

# 验证lipo可用性
which lipo
lipo -v
```

## 常见问题

### Q: 为什么通用二进制体积更大？
A: 通用二进制包含两个架构的代码，体积会是单架构的约1.5-1.8倍，这是正常的。最终DMG包因为压缩算法会有所减小。

### Q: 是否需要在特定Mac上构建？
A: 不需要。您可以在任何macOS机器上构建通用二进制。但出于最优兼容性考虑：
- 建议在Apple Silicon Mac上测试arm64代码
- 建议在Intel Mac上测试x86_64代码

### Q: 如何验证生成的二进制是否为通用格式？
A: 使用以下命令检查：

```bash
file libclash/macos/universal/FlClashCore
# 输出示例: Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64:Mach-O 64-bit executable arm64]

# 或更详细的信息
lipo -info libclash/macos/universal/FlClashCore
# 输出示例: Architectures in the fat file: x86_64 arm64
```

### Q: 构建失败了，如何排查？
A: 查看以下日志：

```bash
# 检查各架构的单独构建输出
ls -la libclash/macos/arm64/
ls -la libclash/macos/amd64/

# 检查lipo合并是否成功
file libclash/macos/universal/FlClashCore
```

## 高级选项

### 自定义构建环境

如果需要指定环境（pre/stable）：

```bash
dart ./setup.dart macos --universal --env stable
dart ./setup.dart macos --universal --env pre
```

### 验证构建完整性

```bash
# 检查两个架构是否正确合并
lipo -verify_arch arm64 x86_64 libclash/macos/universal/FlClashCore

# 提取特定架构进行验证
lipo -thin arm64 -output libclash/macos/universal/FlClashCore.arm64 libclash/macos/universal/FlClashCore
lipo -thin x86_64 -output libclash/macos/universal/FlClashCore.x86_64 libclash/macos/universal/FlClashCore
```

## Xcode 配置变更

本脚本已自动更新了Xcode项目配置：

- **ARCHS** (`$(ARCHS_STANDARD)`) - 支持标准macOS架构（arm64和x86_64）
- **Release/Profile 配置** - 两种配置都已更新支持通用二进制

这些设置在以下文件中：
- `macos/Runner.xcodeproj/project.pbxproj`

## 性能考虑

- **构建时间**: 通用二进制需要约2倍的Core库构建时间（两个架构分别编译）
- **存储空间**: 临时文件占用约500MB-1GB
- **分发包大小**: 最终DMG包约100-200MB（取决于应用大小）

## 相关链接

- [Apple Universal Binary 官方文档](https://developer.apple.com/documentation/xcode/creating_a_universal_macos_binary)
- [lipo 工具参考](https://man7.org/linux/man-pages/man1/lipo.1.html)
- [Flutter macOS 部署指南](https://docs.flutter.dev/deployment/macos)

## 更新记录

- v1.0.0 - 初始版本，支持通用二进制构建和打包
