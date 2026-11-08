# GitHub Actions 自动化打包说明

## 📋 概述

本项目包含两个 GitHub Actions 工作流，用于自动化构建 Flutter 应用的 Windows、Android 和 macOS 版本。

## 🚀 工作流文件

### 1. `build-multiplatform.yml` - 基础版本

**触发方式:**
- 推送 Git 标签（如 `v1.0.0`）时自动触发
- 手动触发（在 GitHub Actions 页面）

**功能:**
- ✅ 构建 Windows x64 便携版（ZIP）
- ✅ 构建 Android APK（分架构）和 AAB
- ✅ 构建 macOS DMG 镜像
- ✅ 自动创建 GitHub Release（仅标签推送）

### 2. `build-advanced.yml` - 高级版本

**触发方式:**
- 推送 Git 标签时自动触发
- 手动触发，可选择构建特定平台

**额外功能:**
- ✅ 支持 Android 代码签名
- ✅ 支持 macOS 代码签名（需配置）
- ✅ 生成详细的发布说明
- ✅ 更灵活的构建选项
- ✅ 生成多种打包格式

## 📝 使用方法

### 方法 1: 推送 Git 标签（推荐）

```bash
# 1. 更新版本号（在 pubspec.yaml）
# 2. 提交更改
git add .
git commit -m "chore: bump version to 2.7.1"

# 3. 创建标签
git tag v2.7.1

# 4. 推送标签（这将触发构建）
git push origin v2.7.1
```

### 方法 2: 手动触发

1. 进入 GitHub 仓库
2. 点击 **Actions** 标签
3. 选择工作流（`多平台打包发布` 或 `高级多平台打包`）
4. 点击 **Run workflow** 按钮
5. 选择分支和选项
6. 点击 **Run workflow** 开始构建

## 🔐 配置代码签名（可选）

### Android 签名

在 GitHub 仓库设置中添加以下 Secrets：

1. **ANDROID_KEYSTORE_BASE64** - 密钥库文件的 Base64 编码
   ```bash
   # 生成 Base64 编码
   base64 -i your-keystore.jks | pbcopy  # macOS
   # 或
   base64 your-keystore.jks | xclip -selection clipboard  # Linux
   ```

2. **ANDROID_KEYSTORE_PASSWORD** - 密钥库密码
3. **ANDROID_KEY_PASSWORD** - 密钥密码
4. **ANDROID_KEY_ALIAS** - 密钥别名

### macOS 签名

1. **MACOS_CERTIFICATE_BASE64** - 开发者证书的 Base64 编码
2. **MACOS_CERTIFICATE_PASSWORD** - 证书密码
3. **MACOS_PROVISIONING_PROFILE_BASE64** - 配置文件（如需要）

## 📦 产物说明

### Windows
- `fl_clash-windows-x64-portable.zip` - 便携版，解压即用

### Android
- `fl_clash-arm64-v8a-release.apk` - 64位 ARM（推荐，适用于大多数现代设备）
- `fl_clash-armeabi-v7a-release.apk` - 32位 ARM（旧设备）
- `fl_clash-x86_64-release.apk` - x86_64（模拟器和部分平板）
- `fl_clash.aab` - Google Play 上架格式

### macOS
- `fl_clash-macos-universal.dmg` - DMG 镜像（推荐）
- `fl_clash-macos-universal.zip` - ZIP 压缩包

## ⏱️ 构建时间

大约需要 15-30 分钟完成所有平台的构建：
- Windows: ~5-8 分钟
- Android: ~8-12 分钟
- macOS: ~6-10 分钟

## 🔍 查看构建状态

1. 进入仓库的 **Actions** 页面
2. 查看正在运行或已完成的工作流
3. 点击具体的运行记录查看详细日志
4. 构建完成后，可以下载产物或查看 Release

## 🛠️ 自定义配置

### 修改 Flutter 版本

在工作流文件中修改 `FLUTTER_VERSION` 环境变量：

```yaml
env:
  FLUTTER_VERSION: '3.24.x'  # 修改为你需要的版本
```

### 只构建特定平台

使用 `build-advanced.yml` 手动触发时，可以取消勾选不需要的平台。

### 修改应用名称

在 `build-advanced.yml` 中修改 `APP_NAME` 环境变量：

```yaml
env:
  APP_NAME: 'fl_clash'  # 修改为你的应用名称
```

## ❗ 常见问题

### Q: 构建失败怎么办？
A: 查看 Actions 页面的详细日志，通常错误信息会指明问题所在。

### Q: 如何测试工作流？
A: 使用手动触发方式，先测试单个平台的构建。

### Q: 为什么 Release 没有自动创建？
A: 只有推送标签时才会自动创建 Release。手动触发需要在高级版本中勾选 "创建 GitHub Release"。

### Q: 构建的应用无法运行？
A: 检查以下几点：
   - 确保所有依赖都在 `pubspec.yaml` 中正确配置
   - 检查本地是否能正常构建
   - 查看构建日志中的警告和错误

## 📚 参考资料

- [Flutter 官方文档](https://flutter.dev/docs)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Flutter 桌面应用构建](https://docs.flutter.dev/deployment/desktop)
- [Android 应用签名](https://docs.flutter.dev/deployment/android#signing-the-app)

## 🤝 贡献

如果你有改进建议，欢迎提交 Pull Request！
