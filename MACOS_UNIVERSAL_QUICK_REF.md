# macOS Universal Binary 快速参考

## 快速命令

### 使用 Makefile（推荐）
```bash
# 构建Universal Binary应用
make macos_universal

# 仅构建Universal Binary核心库
make macos_universal_core

# 单独构建Intel版本
make macos_amd64

# 单独构建Apple Silicon版本
make macos_arm64
```

### 使用 Shell 脚本
```bash
# 构建Universal Binary
./build_macos.sh universal

# 构建单个架构
./build_macos.sh arm64
./build_macos.sh amd64

# 查看详细帮助
./build_macos.sh --help
```

### 直接使用 Dart
```bash
# 完整应用
dart ./setup.dart macos --universal

# 指定环境
dart ./setup.dart macos --universal --env stable

# 仅构建核心库
dart ./setup.dart macos --universal --out core
```

## 验证构建

```bash
# 检查生成的通用二进制
file libclash/macos/universal/FlClashCore

# 查看包含的架构
lipo -info libclash/macos/universal/FlClashCore

# 验证架构完整性
lipo -verify_arch arm64 x86_64 libclash/macos/universal/FlClashCore
```

## 构建输出

```
libclash/macos/
├── arm64/
│   ├── libclash.dylib
│   └── FlClashCore
├── amd64/
│   ├── libclash.dylib
│   └── FlClashCore
└── universal/
    └── FlClashCore    # ← 中间产物：通用二进制
    
dist/
├── mxycloud-universal.dmg   # ← 最终交付物
```

## 系统要求

- macOS 10.15+
- Xcode Command Line Tools (包含 lipo)
- Go 1.13+
- Dart SDK
- Flutter SDK
- Node.js (用于 appdmg)

## 依赖检查

```bash
# 检查 lipo
which lipo
lipo -v

# 检查 Go
go version

# 检查 Dart
dart --version

# 检查 appdmg
npm list -g appdmg
```

## 常见场景

### 场景1: macOS更新后重新构建
```bash
make macos_universal
```

### 场景2: 只更新一个架构的核心库
```bash
dart ./setup.dart macos --arch arm64 --out core
```

### 场景3: 测试构建（不生成DMG）
```bash
# 仅构建核心库
make macos_universal_core

# 验证输出
lipo -info libclash/macos/universal/FlClashCore
```

### 场景4: 清理并重新构建
```bash
# 清理构建产物
rm -rf libclash/macos/
rm -rf build/
rm -rf dist/

# 重新构建
make macos_universal
```

## 故障排除

### 错误：lipo not found
```bash
# 安装 Xcode Command Line Tools
xcode-select --install
```

### 错误：go build 失败
```bash
# 检查 Go 版本
go version

# 检查 CGO 配置
go env CGO_ENABLED
go env CC
```

### 构建超时
```bash
# 增加超时时间或分步构建
dart ./setup.dart macos --arch arm64 --out core
dart ./setup.dart macos --arch amd64 --out core
# 然后手动合并或让脚本处理完整流程
```

## 环境变量

```bash
# 自定义输出目录
export FLUTTER_BUILD_DIR=/custom/path

# 调试模式
export VERBOSE=1

# 指定 Go 编译器
export CC=/path/to/gcc
export GOCACHE=/tmp/gocache
```

## 更多信息

详见 [MACOS_UNIVERSAL_BUILD.md](MACOS_UNIVERSAL_BUILD.md)
