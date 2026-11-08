# 📛 GitHub Actions Badge 徽章

将以下徽章添加到你的 `README.md` 文件中，显示构建状态。

## 基础徽章

### 多平台打包状态

```markdown
[![多平台打包](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml/badge.svg)](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml)
```

### 高级打包状态

```markdown
[![高级打包](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-advanced.yml/badge.svg)](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-advanced.yml)
```

### 构建测试状态

```markdown
[![构建测试](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-test.yml/badge.svg)](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-test.yml)
```

## 带分支的徽章

只显示主分支的构建状态：

```markdown
[![Build Status](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml/badge.svg?branch=main)](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml)
```

## Release 徽章

```markdown
[![GitHub release](https://img.shields.io/github/v/release/你的用户名/pages26-5-10A)](https://github.com/你的用户名/pages26-5-10A/releases/latest)
[![GitHub downloads](https://img.shields.io/github/downloads/你的用户名/pages26-5-10A/total)](https://github.com/你的用户名/pages26-5-10A/releases)
```

## 完整示例

在 README.md 顶部添加：

```markdown
# FL Clash

[![多平台打包](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml/badge.svg)](https://github.com/你的用户名/pages26-5-10A/actions/workflows/build-multiplatform.yml)
[![GitHub release](https://img.shields.io/github/v/release/你的用户名/pages26-5-10A)](https://github.com/你的用户名/pages26-5-10A/releases/latest)
[![GitHub downloads](https://img.shields.io/github/downloads/你的用户名/pages26-5-10A/total)](https://github.com/你的用户名/pages26-5-10A/releases)
[![License](https://img.shields.io/github/license/你的用户名/pages26-5-10A)](LICENSE)

一个基于 ClashMeta 的多平台代理客户端，简单易用，开源无广告。

## 支持平台

- 🪟 Windows (x64)
- 🤖 Android (arm64-v8a, armeabi-v7a, x86_64)
- 🍎 macOS (Universal)

## 下载

前往 [Releases](https://github.com/你的用户名/pages26-5-10A/releases/latest) 页面下载最新版本。
```

## 自定义样式

使用 shields.io 自定义徽章样式：

### 扁平样式
```markdown
![Build](https://img.shields.io/github/actions/workflow/status/你的用户名/pages26-5-10A/build-multiplatform.yml?style=flat)
```

### 扁平方形样式
```markdown
![Build](https://img.shields.io/github/actions/workflow/status/你的用户名/pages26-5-10A/build-multiplatform.yml?style=flat-square)
```

### For the Badge 样式
```markdown
![Build](https://img.shields.io/github/actions/workflow/status/你的用户名/pages26-5-10A/build-multiplatform.yml?style=for-the-badge)
```

### 带颜色的徽章
```markdown
![Build](https://img.shields.io/github/actions/workflow/status/你的用户名/pages26-5-10A/build-multiplatform.yml?style=flat&color=blue)
```

## 平台特定徽章

```markdown
![Windows](https://img.shields.io/badge/Windows-0078D6?style=flat&logo=windows&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=flat&logo=android&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
```

## 技术栈徽章

```markdown
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat&logo=github-actions&logoColor=white)
```

## 使用说明

1. 将 `你的用户名` 替换为你的 GitHub 用户名
2. 如果仓库名不是 `pages26-5-10A`，也需要替换
3. 复制需要的徽章代码到 README.md
4. 提交并推送更改

---

💡 **提示**: 徽章会自动更新，显示最新的构建状态！
