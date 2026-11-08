# 🚀 发布新版本快速指南

## 📋 发布前检查清单

- [ ] 所有功能已完成并测试
- [ ] 更新了版本号（`pubspec.yaml`）
- [ ] 更新了 CHANGELOG（如果有）
- [ ] 本地测试构建通过
- [ ] 代码已推送到主分支

## 🎯 快速发布步骤

### 步骤 1: 更新版本号

编辑 `pubspec.yaml`，更新版本号：

```yaml
version: 2.7.1+2025091116  # 格式: 主版本.次版本.补丁+构建号
```

### 步骤 2: 提交更改

```bash
git add pubspec.yaml
git commit -m "chore: bump version to 2.7.1"
git push origin main
```

### 步骤 3: 创建并推送标签

```bash
# 创建标签（与版本号一致）
git tag v2.7.1

# 推送标签（这将触发自动构建）
git push origin v2.7.1
```

### 步骤 4: 等待构建完成

1. 访问: https://github.com/你的用户名/pages26-5-10A/actions
2. 查看 "多平台打包发布" 工作流运行状态
3. 等待 15-30 分钟，所有平台构建完成

### 步骤 5: 检查 Release

1. 访问: https://github.com/你的用户名/pages26-5-10A/releases
2. 找到新创建的 Release
3. 确认所有文件都已上传：
   - ✅ Windows ZIP
   - ✅ Android APK (多个架构)
   - ✅ Android AAB
   - ✅ macOS DMG

## 🧪 测试发布（推荐）

在正式发布前，先进行测试：

```bash
# 1. 手动触发测试工作流
# 访问 GitHub Actions 页面
# 选择 "构建测试（快速验证）"
# 点击 "Run workflow"
# 选择 "all" 测试所有平台

# 2. 测试通过后再执行正式发布
```

## 📝 版本号规范

遵循语义化版本 (SemVer)：

```
主版本.次版本.补丁+构建号
  ^      ^     ^     ^
  |      |     |     └─ 可选：年月日时分
  |      |     └─ 向后兼容的错误修复
  |      └─ 向后兼容的新功能
  └─ 不兼容的 API 变更
```

**示例:**
- `2.7.0` → `2.7.1` - 修复 bug
- `2.7.0` → `2.8.0` - 新增功能
- `2.7.0` → `3.0.0` - 重大更新

## 🔄 回滚版本

如果发现问题需要回滚：

```bash
# 1. 删除远程标签
git push --delete origin v2.7.1

# 2. 删除本地标签
git tag -d v2.7.1

# 3. 在 GitHub 上删除对应的 Release

# 4. 创建修复后的新版本
git tag v2.7.2
git push origin v2.7.2
```

## 🎨 自定义发布说明

编辑自动生成的 Release 说明：

1. 进入 Release 页面
2. 点击 "Edit release"
3. 修改标题和描述
4. 添加截图、视频等
5. 保存更改

## 📦 手动下载构建产物

如果只需要构建产物，不创建 Release：

1. 手动触发 "多平台打包发布" 工作流
2. 不要选择 "创建 GitHub Release"
3. 构建完成后在 Artifacts 中下载文件

## 🔐 配置签名（首次设置）

### Android 签名

```bash
# 1. 生成密钥库（如果还没有）
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# 2. 转换为 Base64
base64 -i ~/upload-keystore.jks | pbcopy

# 3. 在 GitHub 仓库设置 Secrets:
# ANDROID_KEYSTORE_BASE64 = (粘贴刚才复制的内容)
# ANDROID_KEYSTORE_PASSWORD = (你设置的密钥库密码)
# ANDROID_KEY_PASSWORD = (你设置的密钥密码)
# ANDROID_KEY_ALIAS = upload
```

### macOS 签名

需要 Apple 开发者账号（99美元/年）：

1. 在 Xcode 中导出开发者证书（.p12）
2. 转换为 Base64
3. 在 GitHub 设置 Secrets

## 🐛 常见问题排查

### 构建失败

1. **检查日志**: 在 Actions 页面查看详细错误
2. **本地测试**: 确保本地能正常构建
   ```bash
   flutter build windows --release
   flutter build apk --release
   flutter build macos --release
   ```
3. **依赖问题**: 运行 `flutter pub get` 和 `flutter doctor`

### Release 未创建

- 确认推送的是标签，不是分支
- 检查标签格式是否正确（v开头）
- 查看工作流日志中的错误信息

### 产物大小过大

- 使用 `--split-per-abi` 减小 Android APK 大小
- 使用 `--obfuscate` 混淆代码
- 移除未使用的资源

## 📊 发布统计

在 Release 页面可以查看：
- 下载次数
- 各平台下载分布
- 用户反馈

## 🤝 团队协作

对于团队项目：

1. **保护主分支**: 只有维护者可以推送标签
2. **Code Review**: 发布前进行代码审查
3. **测试环境**: 先在测试分支验证
4. **发布通知**: 更新后通知团队成员

## 📚 相关链接

- [GitHub Actions 文档](https://docs.github.com/actions)
- [Flutter 发布指南](https://flutter.dev/docs/deployment)
- [语义化版本规范](https://semver.org/lang/zh-CN/)

---

💡 **提示**: 首次使用建议先用 "构建测试" 工作流验证配置是否正确！
