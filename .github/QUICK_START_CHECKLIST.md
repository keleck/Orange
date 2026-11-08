# ✅ GitHub Actions 快速上手检查清单

## 📋 首次配置（一次性设置）

### 步骤 1: 启用 GitHub Actions
- [ ] 进入仓库 **Settings** → **Actions** → **General**
- [ ] 选择 **Allow all actions and reusable workflows**
- [ ] 保存设置

### 步骤 2: 验证本地构建（可选但推荐）
```bash
# 检查 Flutter 环境
flutter doctor -v

# 测试本地构建
flutter build windows --release  # Windows
flutter build apk --release      # Android
flutter build macos --release    # macOS
```

- [ ] Windows 构建成功
- [ ] Android 构建成功
- [ ] macOS 构建成功

### 步骤 3: 首次测试（推荐）
- [ ] 访问仓库的 **Actions** 页面
- [ ] 选择 **构建测试（快速验证）** 工作流
- [ ] 点击 **Run workflow**
- [ ] 选择 **all** 测试所有平台
- [ ] 等待构建完成（约 10-15 分钟）
- [ ] 查看日志，确认无错误

---

## 🚀 日常使用（每次发布）

### 快速发布新版本

#### 1. 更新版本号
- [ ] 打开 `pubspec.yaml`
- [ ] 修改 `version: 2.7.1+2025091116`（改为你的新版本号）
- [ ] 保存文件

#### 2. 提交更改（如有其他修改）
```bash
git add .
git commit -m "chore: release v2.7.1"
git push origin main
```
- [ ] 代码已提交
- [ ] 代码已推送

#### 3. 创建并推送标签
```bash
git tag v2.7.1
git push origin v2.7.1
```
- [ ] 标签已创建
- [ ] 标签已推送

#### 4. 等待构建
- [ ] 访问 **Actions** 页面
- [ ] 查看 **多平台打包发布** 工作流运行状态
- [ ] 等待 15-30 分钟

#### 5. 验证发布
- [ ] 访问 **Releases** 页面
- [ ] 确认新版本已创建
- [ ] 检查所有文件都已上传：
  - [ ] Windows ZIP
  - [ ] Android APK (arm64-v8a)
  - [ ] Android APK (armeabi-v7a)
  - [ ] Android APK (x86_64)
  - [ ] Android AAB
  - [ ] macOS DMG

---

## 🔐 可选：配置 Android 签名

### 一次性配置

#### 1. 生成签名密钥（如果还没有）
```bash
keytool -genkey -v -keystore ~/fl-clash-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- [ ] 密钥已生成
- [ ] 密码已记录（重要！）

#### 2. 转换为 Base64
```bash
# macOS
base64 -i ~/fl-clash-upload-keystore.jks | pbcopy
```
- [ ] Base64 已复制到剪贴板

#### 3. 配置 GitHub Secrets
访问 **Settings** → **Secrets and variables** → **Actions**

添加以下 Secrets：
- [ ] `ANDROID_KEYSTORE_BASE64` = (粘贴 Base64)
- [ ] `ANDROID_KEYSTORE_PASSWORD` = (你的密钥库密码)
- [ ] `ANDROID_KEY_PASSWORD` = (你的密钥密码)
- [ ] `ANDROID_KEY_ALIAS` = `upload`

#### 4. 备份密钥（重要！）
```bash
cp ~/fl-clash-upload-keystore.jks ~/安全位置/backup/
```
- [ ] 密钥已备份到安全位置
- [ ] 密码已安全保存

---

## 📊 可选：添加构建状态徽章

### 在 README.md 中添加

```markdown
[![Build Status](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml/badge.svg)](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml)
```

- [ ] 徽章已添加到 README.md
- [ ] 用户名已替换
- [ ] 推送到 GitHub

---

## 🐛 故障排查检查清单

### 如果构建失败

- [ ] 查看 Actions 页面的详细错误日志
- [ ] 确认本地可以正常构建
- [ ] 运行 `flutter doctor` 检查环境
- [ ] 运行 `flutter pub get` 更新依赖
- [ ] 查看 [CI_CD_SETUP.md](CI_CD_SETUP.md) 的故障排查部分

### 如果 Release 未创建

- [ ] 确认推送的是标签，不是分支
- [ ] 检查标签格式（必须是 `v` 开头，如 `v2.7.1`）
- [ ] 查看工作流日志中的 `create-release` 任务

### 如果签名失败

- [ ] 检查所有 4 个 Secrets 都已配置
- [ ] 确认 Base64 编码完整（没有换行）
- [ ] 验证密码正确
- [ ] 参考 [ANDROID_SIGNING_GUIDE.md](ANDROID_SIGNING_GUIDE.md)

---

## 📚 参考文档

根据需要查阅以下文档：

| 文档 | 用途 |
|------|------|
| [SETUP_COMPLETE.md](SETUP_COMPLETE.md) | 配置完成说明 |
| [RELEASE_GUIDE.md](RELEASE_GUIDE.md) | 详细发布指南 |
| [ANDROID_SIGNING_GUIDE.md](ANDROID_SIGNING_GUIDE.md) | Android 签名详解 |
| [CI_CD_SETUP.md](CI_CD_SETUP.md) | 完整配置和故障排查 |
| [BADGES.md](BADGES.md) | 徽章配置 |
| [workflows/README.md](workflows/README.md) | 工作流说明 |

---

## 🎯 成功标志

完成以下任一项即表示配置成功：

✅ **基础成功：** 测试工作流全部通过  
✅ **进阶成功：** 成功发布一个带所有产物的 Release  
✅ **完美成功：** 成功发布带签名的 Android 应用

---

## 💡 快速命令参考

```bash
# 查看当前版本
grep 'version:' pubspec.yaml

# 创建并推送标签（一键发布）
git tag v2.7.1 && git push origin v2.7.1

# 删除标签（如果出错）
git tag -d v2.7.1
git push --delete origin v2.7.1

# 查看所有标签
git tag -l

# 查看最新标签
git describe --tags --abbrev=0
```

---

## ⏱️ 时间预估

| 任务 | 预计时间 |
|------|---------|
| 首次配置（无签名） | 5-10 分钟 |
| 首次配置（含签名） | 20-30 分钟 |
| 首次测试构建 | 10-15 分钟 |
| 日常版本发布 | 2 分钟（创建标签） + 15-30 分钟（等待构建） |

---

## 🎉 完成！

所有检查项都完成后，你就可以：

- ✅ 一键发布多平台应用
- ✅ 自动创建 GitHub Release
- ✅ 让用户轻松下载最新版本
- ✅ 展示专业的构建状态

**开始你的自动化之旅吧！** 🚀

---

💬 **需要帮助？** 查看 [CI_CD_SETUP.md](CI_CD_SETUP.md) 获取详细指南和故障排查！
