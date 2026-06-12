# Flutter 全端构建指南

## 概述

本项目支持以下平台的构建：
- ✅ Android (APK, AAB)
- ✅ iOS (IPA)
- ✅ macOS (DMG, .app)
- ✅ Windows (EXE)
- ✅ Linux (AppImage, DEB)

## 快速开始

### 1. 环境准备

#### 所有平台共同需求
```bash
# 安装 Flutter SDK (3.24.0+)
flutter --version

# 检查环境
flutter doctor -v
```

#### Android 特定需求
```bash
# 需要 Android SDK 和 JDK 17+
flutter doctor --android-licenses
```

#### iOS/macOS 特定需求 (仅 macOS 系统)
```bash
# 需要 Xcode 15+
xcode-select --install
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# 安装 CocoaPods
sudo gem install cocoapods
```

#### Windows 特定需求 (仅 Windows 系统)
```bash
# 需要 Visual Studio 2022 with C++ Desktop Development
```

#### Linux 特定需求 (仅 Linux 系统)
```bash
# 安装构建依赖
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### 2. 使用构建脚本

```bash
# 赋予执行权限
chmod +x build_all_platforms.sh

# 构建所有平台
./build_all_platforms.sh all

# 构建特定平台
./build_all_platforms.sh android
./build_all_platforms.sh ios
./build_all_platforms.sh macos
./build_all_platforms.sh windows
./build_all_platforms.sh linux

# 清理后构建
./build_all_platforms.sh -c android

# 查看帮助
./build_all_platforms.sh --help
```

### 3. 手动构建

#### Android
```bash
# APK (分架构)
flutter build apk --release --split-per-abi

# AAB (Google Play)
flutter build appbundle --release

# 产物位置
build/app/outputs/flutter-apk/
build/app/outputs/bundle/release/
```

#### iOS
```bash
# 无签名构建
flutter build ios --release --no-codesign

# IPA (需要配置签名)
flutter build ipa --release

# 产物位置
build/ios/iphoneos/
build/ios/ipa/
```

#### macOS
```bash
# .app 文件
flutter build macos --release

# DMG 安装包 (需要 flutter_distributor)
flutter_distributor package --platform macos --targets dmg

# 产物位置
build/macos/Build/Products/Release/
dist/
```

#### Windows
```bash
# 构建
flutter build windows --release

# EXE 安装包 (需要 flutter_distributor)
flutter_distributor package --platform windows --targets exe

# 产物位置
build/windows/x64/runner/Release/
dist/
```

#### Linux
```bash
# 构建
flutter build linux --release

# AppImage/DEB (需要 flutter_distributor)
flutter_distributor package --platform linux --targets appimage,deb

# 产物位置
build/linux/x64/release/bundle/
dist/
```

## Git 工作流

### 提交当前更改
```bash
# 查看状态
git status

# 添加所有文件
git add .

# 提交
git commit -m "feat: 添加全端构建支持"

# 推送到远程
git push origin main
```

### 创建发布标签
```bash
# 创建带注释的标签
git tag -a v2.7.0 -m "Release version 2.7.0 with multi-platform support"

# 推送标签到远程
git push origin v2.7.0

# 推送所有标签
git push --tags
```

## GitHub Actions 自动构建

项目已配置 GitHub Actions 工作流 (`.github/workflows/build-all-platforms.yml`)

### 触发方式

1. **自动触发**：推送代码到 `main` 或 `develop` 分支
2. **标签发布**：推送以 `v` 开头的标签（如 `v2.7.0`）
3. **手动触发**：在 GitHub Actions 页面手动运行

### 查看构建结果

1. 访问仓库的 **Actions** 标签页
2. 选择 **Build All Platforms** 工作流
3. 查看构建日志和下载产物

### 发布流程

推送标签后，GitHub Actions 会：
1. 自动构建所有平台
2. 创建 GitHub Release
3. 上传所有构建产物到 Release

## 使用 Flutter Distributor

### 安装
```bash
dart pub global activate flutter_distributor
```

### 配置文件

项目已有配置文件：`distribute_options.yaml`

### 打包命令
```bash
# macOS DMG
flutter_distributor package --platform macos --targets dmg

# Windows EXE
flutter_distributor package --platform windows --targets exe

# Linux AppImage + DEB
flutter_distributor package --platform linux --targets appimage,deb
```

## 常见问题

### 1. Submodule 问题
```bash
# 初始化和更新子模块
git submodule update --init --recursive

# 同步子模块
git submodule sync
git submodule update --remote
```

### 2. 依赖问题
```bash
# 清理并重新获取
flutter clean
flutter pub get

# 重新生成代码
dart run build_runner build --delete-conflicting-outputs
```

### 3. 构建缓存清理
```bash
# 完全清理
flutter clean
rm -rf build/
rm -rf dist/
rm -rf .dart_tool/

# 重新构建
flutter pub get
```

### 4. iOS 签名问题
```bash
# 检查签名配置
security find-identity -v -p codesigning

# 使用 Xcode 管理签名
open ios/Runner.xcworkspace
```

### 5. Android 签名配置

创建 `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=path/to/keystore.jks
```

## 版本管理

### 更新版本号

编辑 `pubspec.yaml`:
```yaml
version: 2.7.0+2025091115
#        主版本.次版本.补丁+构建号
```

### 版本号规范
- 主版本：重大更改
- 次版本：新功能
- 补丁：错误修复
- 构建号：递增数字（用于平台识别）

## 构建产物说明

### Android
- `app-arm64-v8a-release.apk` - ARM64 设备 (主流)
- `app-armeabi-v7a-release.apk` - ARM32 设备 (旧设备)
- `app-x86_64-release.apk` - x86_64 设备 (模拟器)
- `app-release.aab` - Google Play 上传格式

### iOS
- `Runner.app` - iOS 应用包
- `Runner.ipa` - 可分发安装包

### macOS
- `fl_clash.app` - macOS 应用
- `fl_clash-2.7.0-macos.dmg` - DMG 安装包

### Windows
- `fl_clash.exe` - 主程序
- `fl_clash-2.7.0-windows-setup.exe` - 安装程序

### Linux
- `fl_clash-2.7.0-linux.AppImage` - AppImage 格式
- `fl_clash-2.7.0-linux.deb` - Debian 包

## 性能优化建议

### 1. 减小 APK 体积
```bash
# 使用 R8 压缩
flutter build apk --release --shrink

# 分析 APK 大小
flutter build apk --analyze-size
```

### 2. 启用混淆
在 `android/app/build.gradle.kts` 中配置 ProGuard

### 3. Web 优化
```bash
# 构建优化的 Web 版本
flutter build web --release --web-renderer canvaskit
```

## 持续集成最佳实践

1. **缓存依赖**：加速构建
2. **并行构建**：多平台同时构建
3. **增量构建**：仅构建更改的部分
4. **自动测试**：构建前运行单元测试
5. **构建通知**：失败时及时通知

## 资源链接

- [Flutter 官方文档](https://flutter.dev/docs)
- [Flutter Distributor](https://github.com/leanflutter/flutter_distributor)
- [GitHub Actions 文档](https://docs.github.com/actions)
- [Android 发布指南](https://flutter.dev/docs/deployment/android)
- [iOS 发布指南](https://flutter.dev/docs/deployment/ios)

## 技术支持

如有问题，请：
1. 查看 `flutter doctor` 输出
2. 检查构建日志
3. 搜索 GitHub Issues
4. 提交新的 Issue

---

**最后更新**: 2026-06-12
**Flutter 版本**: 3.24.0+
**支持平台**: Android, iOS, macOS, Windows, Linux
