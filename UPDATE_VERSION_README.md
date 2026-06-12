# 版本号批量修改脚本

这个项目包含三个版本的批量修改脚本，可以自动更新 Flutter 项目中所有平台的版本号。

## 支持的平台

- ✅ **Flutter/Dart** - pubspec.yaml
- ✅ **Android** - 通过 Flutter 自动生成
- ✅ **iOS** - Info.plist
- ✅ **macOS** - Info.plist
- ✅ **Windows** - .rc 文件
- ✅ **Linux** - 待增强

## 脚本说明

### 1. Python 版本 (`update_version.py`)

**优点:**
- 跨平台支持好
- 代码清晰易维护
- 错误提示详细

**使用方法:**
```bash
# 基础用法
python3 update_version.py 2.7.0

# 指定项目目录
python3 update_version.py -p /path/to/project 2.7.0

# 带 build 号
python3 update_version.py 2.7.0+2025091201
```

**前置要求:**
- Python 3.6+

### 2. Dart 版本 (`update_version.dart`)

**优点:**
- Flutter 项目推荐使用
- 使用 Dart 语言
- 集成度高

**使用方法:**
```bash
# 基础用法
dart update_version.dart 2.7.0

# 指定项目目录
dart update_version.dart 2.7.0 /path/to/project

# 带 build 号
dart update_version.dart 2.7.0+2025091201
```

**前置要求:**
- Dart SDK（通常随 Flutter 安装）

### 3. Shell 版本 (`update_version.sh`)

**优点:**
- 最轻量
- Unix/Linux 原生支持
- 无额外依赖

**使用方法:**
```bash
# 基础用法
bash update_version.sh 2.7.0

# 指定项目目录
bash update_version.sh 2.7.0 /path/to/project

# 带 build 号
bash update_version.sh 2.7.0+2025091201

# 添加执行权限后直接运行
chmod +x update_version.sh
./update_version.sh 2.7.0
```

**支持系统:**
- macOS
- Linux
- Windows (Git Bash)

## 版本号格式

支持以下版本号格式:

- `X.Y.Z` - 标准语义版本 (例: 2.7.0)
- `X.Y.Z+BuildNumber` - 带 build 号 (例: 2.7.0+2025091201)

在更新时，脚本会：
- 保留原有的 build number
- 自动转换适配不同平台的版本格式

## 更新的文件

脚本会自动查找并更新以下文件:

### 必定更新
- `pubspec.yaml` - version 字段

### 可选更新 (如果存在)
- `ios/**/Info.plist` - CFBundleShortVersionString
- `macos/**/Info.plist` - CFBundleShortVersionString
- `windows/**/*.rc` - FILEVERSION 和 PRODUCTVERSION
- `android/app/build.gradle.kts` - 通过 Flutter 自动生成

## 使用示例

### 场景 1: 更新到 2.7.0 版本

```bash
# 使用 Shell 脚本（最简单）
./update_version.sh 2.7.0
```

输出:
```
🚀 开始更新版本号到: 2.7.0

✅ 更新 pubspec.yaml: 2.6.1+2025091115 -> 2.7.0+2025091115
✅ 更新 ios/Runner/Info.plist: 2.6.1 -> 2.7.0
✅ 更新 macos/Runner/Info.plist: 2.6.1 -> 2.7.0

============================================================
📋 变更总结:
============================================================
✅ 更新 pubspec.yaml: 2.6.1+2025091115 -> 2.7.0+2025091115
✅ 更新 ios/Runner/Info.plist: 2.6.1 -> 2.7.0
✅ 更新 macos/Runner/Info.plist: 2.6.1 -> 2.7.0
============================================================

✨ 版本号更新完成!
```

### 场景 2: 更新到特定 build 号

```bash
python3 update_version.py 2.7.0+2025092401
```

### 场景 3: 在 CI/CD 中使用

```yaml
# GitHub Actions 示例
- name: Update version
  run: |
    python3 update_version.py 2.7.0
```

```yaml
# GitLab CI 示例
update_version:
  script:
    - bash update_version.sh 2.7.0
```

## 常见问题

### Q1: 脚本出错提示找不到文件？
**A:** 确保在项目根目录运行脚本，该目录应包含 `pubspec.yaml`

### Q2: 想只更新特定平台的版本？
**A:** 可以编辑脚本，注释掉不需要的更新函数调用

### Q3: 脚本是否会备份原文件？
**A:** 目前不会，建议在 Git 提交前运行脚本，以便查看变更并回滚

### Q4: 是否支持自动提交和标签？
**A:** 可以编辑脚本添加 Git 操作，或结合脚本使用:
```bash
./update_version.sh 2.7.0
git add .
git commit -m "chore: bump version to 2.7.0"
git tag v2.7.0
```

## 自定义配置

如果需要修改脚本以支持额外的文件或格式，可以编辑对应的脚本文件：

- **Python**: 在 `VersionUpdater` 类中添加新方法
- **Dart**: 在 `VersionUpdater` 类中添加新方法  
- **Shell**: 添加新的 `update_xxx()` 函数

## 许可证

这些脚本可自由使用和修改。

## 相关链接

- [Flutter 官方文档 - 版本管理](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [Semantic Versioning](https://semver.org/)
