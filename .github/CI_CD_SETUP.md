# 🚀 GitHub Actions CI/CD 完整配置指南

## 📋 目录

1. [概述](#概述)
2. [快速开始](#快速开始)
3. [文件说明](#文件说明)
4. [工作流详解](#工作流详解)
5. [配置步骤](#配置步骤)
6. [使用指南](#使用指南)
7. [高级功能](#高级功能)
8. [故障排查](#故障排查)

---

## 概述

本项目已配置完整的 GitHub Actions 自动化流水线，支持：

✅ **Windows** (x64) - 便携版 ZIP  
✅ **Android** (arm64-v8a, armeabi-v7a, x86_64) - APK + AAB  
✅ **macOS** (Universal) - DMG + ZIP  
✅ 自动创建 GitHub Release  
✅ 代码签名支持（可选）  
✅ 构建状态徽章  

---

## 快速开始

### ⚡ 5 分钟快速发布

```bash
# 1. 更新版本号（编辑 pubspec.yaml）
# version: 2.7.1+2025091116

# 2. 提交并推送
git add pubspec.yaml
git commit -m "chore: bump version to 2.7.1"
git push

# 3. 创建并推送标签（触发自动构建）
git tag v2.7.1
git push origin v2.7.1

# 4. 等待 15-30 分钟，访问 Releases 页面下载
```

### 🧪 首次使用建议

先运行测试工作流验证配置：

1. 访问 GitHub Actions 页面
2. 选择 "构建测试（快速验证）"
3. 点击 "Run workflow"
4. 选择 "all" 测试所有平台
5. 等待构建完成（约 5-10 分钟）

---

## 文件说明

### 工作流文件

| 文件 | 说明 | 触发方式 |
|------|------|----------|
| `build-multiplatform.yml` | 基础版 - 三端自动打包 | 推送标签 / 手动触发 |
| `build-advanced.yml` | 高级版 - 包含签名和自定义选项 | 推送标签 / 手动触发 |
| `build-test.yml` | 快速测试 - 验证配置 | 手动触发 |

### 文档文件

| 文件 | 说明 |
|------|------|
| `README.md` | 工作流使用说明 |
| `RELEASE_GUIDE.md` | 发布新版本指南 |
| `ANDROID_SIGNING_GUIDE.md` | Android 签名配置 |
| `BADGES.md` | 徽章配置 |
| `CI_CD_SETUP.md` | 本文件 - 完整配置指南 |

---

## 工作流详解

### 1️⃣ build-multiplatform.yml（基础版）

**特点：**
- 简单易用，开箱即用
- 三个平台并行构建
- 自动创建 Release（仅标签推送）

**适用场景：**
- 日常版本发布
- 不需要代码签名
- 快速打包测试

**产物：**
- Windows: `fl_clash-windows-x64.zip`
- Android: `fl_clash-arm64-v8a.apk` 等
- macOS: `fl_clash-macos.dmg`

### 2️⃣ build-advanced.yml（高级版）

**特点：**
- 支持 Android/macOS 代码签名
- 灵活的构建选项
- 详细的发布说明
- 多种打包格式

**适用场景：**
- 正式发布到应用商店
- 需要代码签名的版本
- 企业分发

**产物：**
- Windows: 便携版 ZIP + 安装器（可选）
- Android: APK（多架构） + AAB
- macOS: DMG + ZIP

### 3️⃣ build-test.yml（测试版）

**特点：**
- Debug 模式构建（更快）
- 单平台或全平台测试
- 不创建 Release

**适用场景：**
- 验证配置是否正确
- 测试依赖是否完整
- CI 环境调试

---

## 配置步骤

### 第一步：启用 GitHub Actions

1. 进入 GitHub 仓库
2. 点击 **Settings** → **Actions** → **General**
3. 确保 **Allow all actions and reusable workflows** 已选中
4. 保存设置

### 第二步：配置 Secrets（可选）

如果需要代码签名，配置以下 Secrets：

#### Android 签名

| Secret 名称 | 说明 |
|------------|------|
| `ANDROID_KEYSTORE_BASE64` | 密钥库文件的 Base64 编码 |
| `ANDROID_KEYSTORE_PASSWORD` | 密钥库密码 |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名（通常是 "upload"） |

详细步骤见 [ANDROID_SIGNING_GUIDE.md](ANDROID_SIGNING_GUIDE.md)

#### macOS 签名

| Secret 名称 | 说明 |
|------------|------|
| `MACOS_CERTIFICATE_BASE64` | 开发者证书的 Base64 编码 |
| `MACOS_CERTIFICATE_PASSWORD` | 证书密码 |

*注：macOS 签名需要 Apple 开发者账号（$99/年）*

### 第三步：验证配置

```bash
# 本地测试构建
flutter build windows --release
flutter build apk --release
flutter build macos --release

# 检查依赖
flutter doctor -v
flutter pub get
```

### 第四步：首次运行

使用测试工作流验证：

1. 访问 **Actions** → **构建测试**
2. 点击 **Run workflow**
3. 选择 **all**
4. 查看构建日志

---

## 使用指南

### 场景 1: 日常开发测试

```bash
# 手动触发测试工作流
# 在 GitHub Actions 页面操作
```

### 场景 2: 发布正式版本

```bash
# 1. 更新版本号
vim pubspec.yaml  # version: 2.7.1+2025091116

# 2. 提交代码
git add .
git commit -m "chore: release v2.7.1"
git push

# 3. 创建并推送标签
git tag v2.7.1
git push origin v2.7.1

# 4. 等待自动构建和发布
```

### 场景 3: 紧急修复

```bash
# 1. 修复问题
git commit -am "fix: critical bug"
git push

# 2. 创建补丁版本
git tag v2.7.2
git push origin v2.7.2
```

### 场景 4: 测试特定平台

```bash
# 使用高级工作流手动触发
# 只勾选需要的平台（如 Android）
```

---

## 高级功能

### 自定义 Flutter 版本

编辑工作流文件：

```yaml
env:
  FLUTTER_VERSION: '3.24.x'  # 修改为需要的版本
```

### 添加构建前脚本

在构建步骤前添加：

```yaml
- name: 运行构建前脚本
  run: |
    bash scripts/pre-build.sh
```

### 配置构建缓存

已默认启用：

```yaml
- uses: subosito/flutter-action@v2
  with:
    cache: true  # 启用缓存，加速构建
```

### 自定义产物名称

修改工作流中的产物名称：

```yaml
- name: 重命名产物
  run: |
    mv app-release.apk myapp-v${{ github.ref_name }}.apk
```

### 添加通知

在工作流末尾添加：

```yaml
- name: 发送通知
  if: success()
  run: |
    curl -X POST https://your-webhook-url \
      -d "text=构建成功！版本 ${{ github.ref_name }}"
```

---

## 故障排查

### ❌ 问题 1: 构建失败 - 依赖错误

**症状：** `flutter pub get` 失败

**解决方案：**
```bash
# 本地测试
flutter clean
flutter pub get
flutter pub outdated

# 检查 pubspec.yaml 中的依赖版本
```

### ❌ 问题 2: Android 签名失败

**症状：** 签名配置错误

**解决方案：**
1. 检查 Secrets 是否正确配置
2. 验证 Base64 编码是否完整
3. 确认密码正确

```bash
# 本地测试签名
flutter build apk --release
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

### ❌ 问题 3: macOS 构建失败

**症状：** 找不到 App 产物

**解决方案：**
```bash
# 检查应用名称
ls build/macos/Build/Products/Release/

# 修改工作流中的应用名称
```

### ❌ 问题 4: Release 未创建

**症状：** 构建成功但没有 Release

**原因：** 
- 只有推送标签才会自动创建 Release
- 手动触发不会创建（除非使用高级版并勾选选项）

**解决方案：**
```bash
# 推送标签
git tag v2.7.1
git push origin v2.7.1
```

### ❌ 问题 5: 构建超时

**症状：** 构建运行时间过长被中断

**解决方案：**
1. 检查是否有死循环的测试
2. 减少并行构建任务
3. 使用构建缓存

### ❌ 问题 6: Windows 构建卡住

**症状：** Windows 构建一直运行

**解决方案：**
- 检查是否有交互式命令
- 确保所有命令都能自动完成

---

## 性能优化

### 1. 启用缓存

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.pub-cache
      ~/.gradle/caches
    key: ${{ runner.os }}-build-${{ hashFiles('**/pubspec.lock') }}
```

### 2. 并行构建

三个平台已默认并行构建，无需额外配置。

### 3. 减少产物大小

```yaml
# Android - 分架构构建
flutter build apk --split-per-abi

# 启用混淆
flutter build apk --obfuscate --split-debug-info=./debug-info
```

---

## 安全最佳实践

### ✅ DO（推荐做法）

- ✅ 使用 GitHub Secrets 存储敏感信息
- ✅ 将 `key.properties` 和 `*.jks` 添加到 `.gitignore`
- ✅ 定期更新 Flutter 和依赖版本
- ✅ 备份签名密钥到安全位置
- ✅ 使用最小权限原则配置 Secrets

### ❌ DON'T（避免做法）

- ❌ 将密钥文件提交到 Git
- ❌ 在代码中硬编码密码
- ❌ 共享私钥给未授权人员
- ❌ 使用不安全的密钥库密码
- ❌ 忽略安全警告

---

## 监控和维护

### 查看构建历史

访问：`https://github.com/你的用户名/pages26-5-10A/actions`

### 添加状态徽章

在 README.md 中添加：

```markdown
[![Build Status](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml/badge.svg)](https://github.com/你的用户名/pages26-5-10A/actions)
```

详见 [BADGES.md](BADGES.md)

### 定期维护

- 每月检查依赖更新
- 每季度更新 Flutter 版本
- 每年更新签名证书（如需要）

---

## 成本估算

GitHub Actions 免费额度：

| 账户类型 | 每月免费分钟数 |
|---------|--------------|
| 个人（Public Repo） | 无限 |
| 个人（Private Repo） | 2,000 分钟 |
| 组织（Private Repo） | 2,000 分钟 |

**消耗估算（每次完整构建）：**
- Linux (Android): ~600 分钟
- Windows: ~800 分钟  
- macOS: ~1,000 分钟  
- **总计：** ~2,400 分钟（换算后）

*注：不同平台消耗倍率不同，详见 [GitHub 定价](https://docs.github.com/en/billing/managing-billing-for-github-actions)*

---

## 🎓 学习资源

- [GitHub Actions 官方文档](https://docs.github.com/en/actions)
- [Flutter CI/CD 指南](https://docs.flutter.dev/deployment/cd)
- [Flutter 构建模式](https://docs.flutter.dev/testing/build-modes)
- [Android 应用签名](https://developer.android.com/studio/publish/app-signing)

---

## 🤝 贡献

欢迎提交改进建议！如果你发现问题或有更好的配置方案，请创建 Issue 或 Pull Request。

---

## 📄 许可证

本 CI/CD 配置采用 MIT 许可证，可自由使用和修改。

---

**最后更新:** 2025-01-11  
**维护者:** FL Clash Team  
**版本:** 1.0.0

---

💡 **提示**: 如有问题，请先查看 [故障排查](#故障排查) 部分！
