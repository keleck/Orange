# 🚀 Flutter 全端构建工具包

本工具包提供了完整的 Git 工作流和多平台构建解决方案。

## 📦 工具清单

| 工具 | 文件 | 说明 |
|------|------|------|
| **全端构建** | `build_all_platforms.sh` | 一键构建所有平台 (Android/iOS/macOS/Windows/Linux) |
| **Git 工作流** | `git_workflow.sh` | Git 提交、推送、发布管理 |
| **快速部署** | `quick_deploy.sh` | 一键提交、推送、构建、发布 |
| **GitHub Actions** | `.github/workflows/build-all-platforms.yml` | 自动化 CI/CD 流程 |
| **详细文档** | `MULTI_PLATFORM_BUILD_GUIDE.md` | 完整的构建指南 |

## 🎯 快速开始

### 方式一：使用快速部署脚本（推荐）

```bash
# 一键完成：提交、推送、构建、发布
./quick_deploy.sh
```

这个脚本会引导你完成：
1. ✅ 查看当前更改
2. ✅ 提交代码
3. ✅ 推送到远程
4. ✅ 创建发布标签（可选）
5. ✅ 本地构建（可选）

### 方式二：分步执行

#### 1. Git 工作流

```bash
# 查看状态
./git_workflow.sh status

# 提交更改
./git_workflow.sh commit

# 推送代码
./git_workflow.sh push

# 创建发布版本
./git_workflow.sh release

# 同步子模块
./git_workflow.sh sync
```

#### 2. 本地构建

```bash
# 构建所有平台
./build_all_platforms.sh all

# 构建特定平台
./build_all_platforms.sh android
./build_all_platforms.sh macos
./build_all_platforms.sh windows

# 清理后构建
./build_all_platforms.sh -c android

# 查看帮助
./build_all_platforms.sh --help
```

## 🔄 标准发布流程

### 完整发布流程

```bash
# 步骤 1: 更新版本号
# 编辑 pubspec.yaml，修改 version 字段

# 步骤 2: 提交所有更改
./git_workflow.sh commit

# 步骤 3: 推送到远程
./git_workflow.sh push

# 步骤 4: 创建发布标签
./git_workflow.sh release

# 步骤 5: GitHub Actions 自动构建
# 访问 https://github.com/你的仓库/actions 查看构建进度
```

### 或者使用一键脚本

```bash
./quick_deploy.sh
# 按提示操作即可完成所有步骤
```

## 🤖 GitHub Actions 自动构建

### 触发方式

推送标签后，GitHub Actions 会自动：
1. 构建所有平台（并行执行）
2. 运行测试（如果配置）
3. 创建 GitHub Release
4. 上传所有构建产物

### 查看构建状态

```bash
# 访问你的仓库
https://github.com/你的用户名/你的仓库名/actions
```

### 手动触发构建

在 GitHub Actions 页面：
1. 选择 "Build All Platforms" 工作流
2. 点击 "Run workflow"
3. 选择要构建的平台
4. 点击 "Run workflow" 按钮

## 📱 支持的平台

| 平台 | 产物格式 | 构建命令 |
|------|----------|----------|
| **Android** | APK, AAB | `./build_all_platforms.sh android` |
| **iOS** | IPA | `./build_all_platforms.sh ios` |
| **macOS** | DMG, .app | `./build_all_platforms.sh macos` |
| **Windows** | EXE | `./build_all_platforms.sh windows` |
| **Linux** | AppImage, DEB | `./build_all_platforms.sh linux` |

## 🛠️ 环境要求

### 所有平台
- Flutter SDK 3.24.0+
- Dart SDK 3.1.0+
- Git

### Android
- Android SDK
- JDK 17+

### iOS/macOS（仅 macOS 系统）
- Xcode 15+
- CocoaPods

### Windows（仅 Windows 系统）
- Visual Studio 2022
- C++ Desktop Development

### Linux（仅 Linux 系统）
- clang, cmake, ninja-build
- GTK 3.0+

## 📂 构建产物位置

所有构建产物会保存在 `dist/` 目录：

```
dist/
├── android/
│   ├── app-arm64-v8a-release.apk
│   ├── app-armeabi-v7a-release.apk
│   ├── app-x86_64-release.apk
│   └── app-release.aab
├── ios/
│   └── Runner.ipa
├── macos/
│   ├── fl_clash.app
│   └── fl_clash-2.7.0-macos.dmg
├── windows/
│   └── fl_clash-2.7.0-windows-setup.exe
└── linux/
    ├── fl_clash-2.7.0-linux.AppImage
    └── fl_clash-2.7.0-linux.deb
```

## 🐛 常见问题

### 1. 子模块未初始化

```bash
./git_workflow.sh sync
```

### 2. 构建失败

```bash
# 清理并重试
flutter clean
flutter pub get
./build_all_platforms.sh -c <platform>
```

### 3. 推送失败

```bash
# 检查远程仓库
git remote -v

# 添加远程仓库（如果没有）
git remote add origin <repository-url>
```

### 4. 标签已存在

```bash
# 删除本地标签
git tag -d v2.7.0

# 删除远程标签
git push origin :refs/tags/v2.7.0
```

## 📚 更多文档

详细文档请查看：
- **构建指南**: `MULTI_PLATFORM_BUILD_GUIDE.md`
- **Flutter 文档**: https://flutter.dev/docs
- **GitHub Actions 文档**: https://docs.github.com/actions

## 💡 最佳实践

### 版本号管理
```yaml
# pubspec.yaml
version: 主版本.次版本.补丁+构建号
# 例如: 2.7.0+2025091115
```

### 提交信息规范
```bash
feat: 新功能
fix: 错误修复
docs: 文档更新
style: 代码格式
refactor: 重构
test: 测试
chore: 构建/工具
```

### 分支策略
- `main`: 生产环境
- `develop`: 开发环境
- `feature/*`: 功能分支
- `hotfix/*`: 紧急修复

## 🎉 使用示例

### 场景 1: 日常开发提交

```bash
# 开发完成后
./git_workflow.sh commit
./git_workflow.sh push
```

### 场景 2: 发布新版本

```bash
# 1. 更新版本号 (pubspec.yaml)
# 2. 一键发布
./quick_deploy.sh
# 选择 "y" 创建发布版本
```

### 场景 3: 仅本地测试

```bash
# 构建并测试
./build_all_platforms.sh android
# 在设备上安装 dist/android/app-arm64-v8a-release.apk
```

### 场景 4: 紧急修复

```bash
# 1. 修复 bug
# 2. 快速部署
./quick_deploy.sh
```

---

**提示**: 所有脚本都支持 `--help` 参数查看详细用法

```bash
./build_all_platforms.sh --help
./git_workflow.sh --help
```

**首次使用**: 确保所有脚本有执行权限
```bash
chmod +x *.sh
```
