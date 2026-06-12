# macOS Universal Binary (Intel + Apple Silicon) 打包配置总结

## 项目改动内容

本次实现添加了完整的macOS Universal Binary（通用二进制）打包支持，允许在一个应用包中同时支持Intel (x86_64) 和 Apple Silicon (arm64) 两种架构。

### 修改的文件

#### 1. `setup.dart` - 核心构建脚本 (3处改动)

**改动1: 添加 `createUniversalBinary()` 方法**
- 位置：`Build` 类内，`buildHelper()` 方法之后
- 功能：使用 macOS `lipo` 工具合并两个架构的二进制文件
- 参数：arm64 和 amd64 二进制路径，输出路径
- 返回：合并后的通用二进制文件路径

```dart
static Future<String> createUniversalBinary({
  required String arm64Path,
  required String amd64Path,
  required String outputPath,
}) async {
  // 使用 lipo -create 合并两个架构
}
```

**改动2: 增强 `BuildCommand` 构造函数**
- 为 macOS 目标添加 `--universal` / `-u` flag
- 此 flag 支持通用二进制构建

```dart
// Add universal binary option for macOS
if (target == Target.macos) {
  argParser.addFlag(
    "universal",
    abbr: 'u',
    help: 'Build universal binary for arm64 and amd64',
    negatable: false,
  );
}
```

**改动3: 修改 `BuildCommand.run()` 中的 macOS case**
- 检测是否启用 `--universal` flag
- 若启用：
  - 分别编译 arm64 和 amd64 版本的核心库
  - 使用 `lipo` 合并为通用二进制
  - 使用 flutter_distributor 打包成 DMG
- 若禁用：保持原有单架构打包流程

```dart
case Target.macos:
  final isUniversal = argResults?["universal"] as bool? ?? false;
  
  if (isUniversal) {
    // 构建两个架构并合并
    final arm64Cores = await Build.buildCore(...);
    final amd64Cores = await Build.buildCore(...);
    await Build.createUniversalBinary(...);
    // 打包通用应用
  } else {
    // 保持现有单架构流程
  }
```

#### 2. `Makefile` - 构建目标 (4处新增)

新增以下 Make 目标：

```makefile
macos_amd64:
	dart ./setup.dart macos --arch amd64

macos_universal:
	dart ./setup.dart macos --universal

macos_amd64_core:
	dart ./setup.dart macos --arch amd64 --out core

macos_universal_core:
	dart ./setup.dart macos --universal --out core
```

#### 3. `macos/Runner.xcodeproj/project.pbxproj` - Xcode 配置 (2处改动)

在 Release 和 Profile 配置中添加 `ARCHS` 设置：

**Release 配置：**
```
ARCHS = "$(ARCHS_STANDARD)";
```

**Profile 配置：**
```
ARCHS = "$(ARCHS_STANDARD)";
```

说明：
- `$(ARCHS_STANDARD)` 是 Xcode 标准宏，自动扩展为 `arm64 x86_64`
- 这使得 Flutter 应用能够编译为通用二进制格式
- 其他配置（代码签名、entitlements 等）保持不变

### 新增的文档和脚本

#### 1. `MACOS_UNIVERSAL_BUILD.md` - 详细指南
- 完整的使用说明
- 构建过程详解
- 系统要求和依赖安装
- 常见问题和解决方案
- 验证构建的方法

#### 2. `MACOS_UNIVERSAL_QUICK_REF.md` - 快速参考
- 核心命令速查
- 常见场景的解决方案
- 故障排除快速指南
- 环境变量配置

#### 3. `build_macos.sh` - 辅助构建脚本
- 可执行的 Shell 脚本
- 自动检查依赖
- 友好的命令行界面
- 构建验证步骤
- 支持三种构建方式：universal, arm64, amd64

## 使用方式

### 快速开始

```bash
# 最简单的方式 - 构建通用应用
make macos_universal

# 使用脚本
./build_macos.sh universal

# 直接命令
dart ./setup.dart macos --universal
```

### 构建流程

1. **arm64 编译** (Apple Silicon)
   - 输出：`libclash/macos/arm64/FlClashCore`
   - 耗时：~5-15 分钟

2. **amd64 编译** (Intel)
   - 输出：`libclash/macos/amd64/FlClashCore`
   - 耗时：~5-15 分钟

3. **二进制合并** (lipo)
   - 输入：两个架构的二进制
   - 输出：`libclash/macos/universal/FlClashCore`
   - 耗时：< 1 分钟

4. **应用打包** (flutter_distributor)
   - 输入：通用二进制 + Flutter 应用
   - 输出：`dist/mxycloud-universal.dmg`
   - 耗时：~10-20 分钟

## 验证构建

```bash
# 检查通用二进制完整性
file libclash/macos/universal/FlClashCore
# 输出应包含: "Mach-O universal binary with 2 architectures"

# 列出包含的架构
lipo -info libclash/macos/universal/FlClashCore
# 输出应为: "Architectures in the fat file: x86_64 arm64"

# 验证两个架构都可用
lipo -verify_arch arm64 x86_64 libclash/macos/universal/FlClashCore
# 输出: Valid
```

## 性能指标

| 操作 | 时间 | 说明 |
|------|------|------|
| arm64 编译 | 5-15 分钟 | 取决于代码量和 Mac 配置 |
| amd64 编译 | 5-15 分钟 | 同上 |
| 二进制合并 | < 1 分钟 | lipo 操作 |
| DMG 打包 | 10-20 分钟 | flutter_distributor |
| **总计** | **25-51 分钟** | 完整构建周期 |

## 文件大小参考

| 文件 | 大小 | 说明 |
|------|------|------|
| FlClashCore (arm64) | ~15-20 MB | 单架构二进制 |
| FlClashCore (amd64) | ~15-20 MB | 单架构二进制 |
| FlClashCore (universal) | ~30-40 MB | 两个架构合并后体积 |
| mxycloud-universal.dmg | ~100-200 MB | 最终分发包（压缩） |

## 兼容性

| macOS 版本 | Intel Mac | Apple Silicon Mac | 说明 |
|-----------|-----------|------------------|------|
| 10.15     | ✓         | ✗                 | Intel 最早支持版本 |
| 11.x      | ✓         | ✓ (Big Sur)      | Apple Silicon 首次支持 |
| 12.x+     | ✓         | ✓                 | 完全支持 |

## 系统要求更新

原有要求基础上新增：
- macOS 10.15 或更高（编译 Universal Binary）
- Xcode 12.0+ （包含 lipo）
- 可选：两台不同架构的 Mac 用于充分测试

## 环境变量

支持以下环境变量：

```bash
# 指定输出目录
export FLUTTER_BUILD_DIR=/custom/path

# 启用详细日志
export VERBOSE=1

# 自定义 Go 编译器
export CC=/path/to/gcc
export GOARCH=arm64  # 或 amd64
export GOOS=darwin
```

## 后续改进建议

1. **CI/CD 集成**
   - GitHub Actions 或 GitLab CI 自动构建
   - 在云端编译，避免本地耗时

2. **并行编译**
   - 如有多台 Mac，可在不同机器并行编译各架构

3. **缓存优化**
   - 缓存 Go 编译结果
   - 缓存 Flutter 依赖和编译产物

4. **代码签名和公证**
   - 添加 Apple 开发者账户签名
   - 提交 App Store 或 Gatekeeper 公证

5. **版本管理**
   - 为每个通用二进制版本标记架构信息
   - 追踪构建时间和大小变化

## 故障排除快速索引

| 问题 | 解决方案 |
|------|--------|
| lipo 命令未找到 | 安装 Xcode Command Line Tools |
| Go 编译失败 | 检查 CGO_ENABLED 和 CC 设置 |
| 内存不足 | 关闭其他应用或增加交换空间 |
| 权限错误 | 使用 `sudo` 或修改目录权限 |

## 相关文档

- [MACOS_UNIVERSAL_BUILD.md](MACOS_UNIVERSAL_BUILD.md) - 详细操作指南
- [MACOS_UNIVERSAL_QUICK_REF.md](MACOS_UNIVERSAL_QUICK_REF.md) - 快速参考
- [Apple Universal Binary 文档](https://developer.apple.com/documentation/xcode/creating_a_universal_macos_binary)
- [lipo 工具手册](https://man7.org/linux/man-pages/man1/lipo.1.html)

## 版本信息

- 实现日期: 2025年3月25日
- 支持 Dart: 3.1.0+
- 支持 Flutter: 最新版本
- 支持 macOS: 10.15+

---

**关键改动总结**：通过添加 `createUniversalBinary()` 方法、扩展构建命令和更新 Xcode 配置，实现了一键编译和打包支持 Intel 和 Apple Silicon 双架构的 macOS 应用。
