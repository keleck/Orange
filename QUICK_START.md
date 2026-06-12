# ⚡ 快速开始指南

## 🎯 三步完成全端构建和发布

### 方法一：一键部署（推荐）

```bash
./quick_deploy.sh
```

按照提示完成：提交 → 推送 → 发布 → 构建

---

### 方法二：使用独立脚本

#### Step 1: 提交代码

```bash
./git_workflow.sh commit
```

#### Step 2: 推送到远程

```bash
./git_workflow.sh push
```

#### Step 3: 创建发布版本（触发 CI/CD）

```bash
./git_workflow.sh release
```

这会自动触发 GitHub Actions 构建所有平台！

---

### 方法三：本地构建

```bash
# 构建所有平台
./build_all_platforms.sh all

# 或者构建特定平台
./build_all_platforms.sh android
./build_all_platforms.sh macos
```

构建产物在 `dist/` 目录。

---

## 📋 常用命令速查

| 操作 | 命令 |
|------|------|
| **查看状态** | `./git_workflow.sh status` |
| **提交更改** | `./git_workflow.sh commit` |
| **推送代码** | `./git_workflow.sh push` |
| **发布版本** | `./git_workflow.sh release` |
| **同步子模块** | `./git_workflow.sh sync` |
| **构建 Android** | `./build_all_platforms.sh android` |
| **构建 macOS** | `./build_all_platforms.sh macos` |
| **构建所有平台** | `./build_all_platforms.sh all` |
| **一键部署** | `./quick_deploy.sh` |

---

## 🔍 查看构建结果

### GitHub Actions（自动构建）

1. 访问: `https://github.com/你的用户名/你的仓库/actions`
2. 查看 "Build All Platforms" 工作流
3. 下载构建产物

### 本地构建

```bash
ls -lh dist/
```

---

## 📦 构建产物说明

| 平台 | 文件 | 位置 |
|------|------|------|
| Android | `*.apk`, `*.aab` | `dist/android/` |
| iOS | `*.ipa` | `dist/ios/` |
| macOS | `*.dmg`, `*.app` | `dist/macos/` |
| Windows | `*.exe` | `dist/windows/` |
| Linux | `*.AppImage`, `*.deb` | `dist/linux/` |

---

## 🚨 首次使用

1. **确保脚本可执行**
   ```bash
   chmod +x *.sh
   ```

2. **检查 Flutter 环境**
   ```bash
   flutter doctor -v
   ```

3. **配置远程仓库**（如果还没有）
   ```bash
   git remote add origin <你的仓库URL>
   ```

4. **初始化子模块**
   ```bash
   ./git_workflow.sh sync
   ```

---

## 💡 完整发布流程示例

```bash
# 1. 修改版本号（编辑 pubspec.yaml）
# version: 2.7.1+2025091116

# 2. 运行一键部署
./quick_deploy.sh

# 提示时输入:
# - 提交信息: feat: 发布 v2.7.1
# - 是否创建发布: y
# - 新版本号: 2.7.1
# - 发布说明: 添加新功能和修复 bug

# 3. 等待 GitHub Actions 自动构建所有平台

# 4. 在 GitHub Releases 页面下载构建产物
```

---

## 📚 详细文档

- **完整构建指南**: `MULTI_PLATFORM_BUILD_GUIDE.md`
- **工具说明**: `BUILD_README.md`
- **GitHub Actions**: `.github/workflows/build-all-platforms.yml`

---

## ❓ 遇到问题？

### 子模块问题
```bash
./git_workflow.sh sync
```

### 构建失败
```bash
flutter clean
flutter pub get
./build_all_platforms.sh -c <platform>
```

### 查看帮助
```bash
./build_all_platforms.sh --help
./git_workflow.sh --help
```

---

**💡 提示**: 推荐使用 `./quick_deploy.sh` 进行日常开发和发布！
