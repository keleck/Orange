#!/usr/bin/env bash

# macOS Universal Binary Build - Quick Start Guide
# 快速开始指南 - macOS 双架构应用打包

cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════════════╗
║                   macOS Universal Binary Build System                      ║
║              Intel (x86_64) + Apple Silicon (arm64) 双架构打包           ║
╚═══════════════════════════════════════════════════════════════════════════╝

📦 新功能：一键生成支持 Intel 和 Apple Silicon 的通用 macOS 应用

═══════════════════════════════════════════════════════════════════════════════

🚀 最快的开始方式：

  # 构建通用应用（包含完整SDK）
  make macos_universal

  # 或使用脚本
  ./build_macos.sh universal

  # 或直接用 Dart
  dart ./setup.dart macos --universal

═══════════════════════════════════════════════════════════════════════════════

📝 可用命令列表：

【 Makefile 目标（最推荐）】
  make macos_universal          构建通用应用（arm64 + x86_64）
  make macos_universal_core     仅构建通用核心库
  make macos_arm64              Apple Silicon 应用（单架构）
  make macos_amd64              Intel 应用（单架构）
  make macos_arm64_core         Apple Silicon 核心库（单架构）
  make macos_amd64_core         Intel 核心库（单架构）

【 Shell 脚本选项】
  ./build_macos.sh universal    构建通用应用
  ./build_macos.sh universal app stable    指定环境为 stable
  ./build_macos.sh arm64        构建 Apple Silicon 应用
  ./build_macos.sh amd64        构建 Intel 应用
  ./build_macos.sh --help       查看完整帮助信息

【 Dart 直接命令】
  dart ./setup.dart macos --universal              构建通用应用
  dart ./setup.dart macos -u                       使用缩写
  dart ./setup.dart macos --universal --env pre    指定环境为 pre
  dart ./setup.dart macos --universal --out core   仅构建核心库
  dart ./setup.dart macos --arch amd64             Intel 单架构
  dart ./setup.dart macos --arch arm64             Apple Silicon 单架构

═══════════════════════════════════════════════════════════════════════════════

✅ 验证构建成功：

  # 检查通用二进制
  file libclash/macos/universal/FlClashCore
  # 应该输出: Mach-O universal binary with 2 architectures

  # 查看包含的架构
  lipo -info libclash/macos/universal/FlClashCore
  # 应该输出: Architectures in the fat file: x86_64 arm64

═══════════════════════════════════════════════════════════════════════════════

📊 构建时间和产物：

  ARM64 编译      5-15 分钟   → libclash/macos/arm64/FlClashCore
  AMD64 编译      5-15 分钟   → libclash/macos/amd64/FlClashCore
  二进制合并      < 1 分钟    → libclash/macos/universal/FlClashCore
  DMG 打包        10-20 分钟  → dist/mxycloud-universal.dmg
  ─────────────────────────────────────────────────────────
  总耗时          25-51 分钟  完整构建周期（首次较长）

═══════════════════════════════════════════════════════════════════════════════

🔧 系统要求检查：

  macOS 10.15+              ✓ 编译目标最低版本
  Xcode Command Line Tools  # xcode-select --install
  Go 1.13+                  # go version
  Dart SDK                  # dart --version
  Flutter SDK               # flutter --version
  Node.js + npm             # npm install -g appdmg

═══════════════════════════════════════════════════════════════════════════════

💡 常见场景：

【 场景 1 】想构建完整通用应用（这是大多数情况）
  $ make macos_universal
  完成后在 dist/ 找到 mxycloud-universal.dmg

【 场景 2 】只想构建核心库用于测试
  $ make macos_universal_core
  完成后在 libclash/macos/universal/ 找到 FlClashCore

【 场景 3 】只需要 Apple Silicon 版本
  $ make macos_arm64
  或 $ dart ./setup.dart macos --arch arm64

【 场景 4 】只需要 Intel 版本
  $ make macos_amd64
  或 $ dart ./setup.dart macos --arch amd64

【 场景 5 】构建失败想重新开始
  $ rm -rf libclash/macos/ build/ dist/
  $ make macos_universal

═══════════════════════════════════════════════════════════════════════════════

📚 详细文档：

  • MACOS_UNIVERSAL_BUILD.md      - 完整操作指南
  • MACOS_UNIVERSAL_QUICK_REF.md  - 快速参考卡片
  • IMPLEMENTATION_SUMMARY.md     - 技术实现细节
  • build_macos.sh               - 增强脚本（含验证）

═══════════════════════════════════════════════════════════════════════════════

⚠️ 常见问题快速解决：

【 问题：lipo: command not found 】
  解决：xcode-select --install

【 问题：已安装 Xcode 中有 lipo 】
  验证：which lipo ; lipo -v

【 问题：构建超时（大于 2 小时）】
  解决：可能是网络问题或硬盘速度，重试或检查磁盘空间
       disk free -h

【 问题：权限被拒绝 /usr/local/bin 】
  解决：appdmg 或其他工具可能需要 sudo
       sudo npm install -g appdmg

═══════════════════════════════════════════════════════════════════════════════

🎯 下一步：

  1. 运行构建：
     make macos_universal

  2. 等待完成（咖啡时间 ☕）

  3. 验证产物：
     ls -lh dist/
     file libclash/macos/universal/FlClashCore

  4. 测试应用：
     # 在 Intel Mac 和 Apple Silicon Mac 上都能运行

  5. 分发：
     # 将 dist/mxycloud-universal.dmg 分享给用户

═══════════════════════════════════════════════════════════════════════════════

💬 获取帮助：

  # 更多说明
  cat MACOS_UNIVERSAL_QUICK_REF.md

  # 脚本帮助
  ./build_macos.sh --help

  # 查看源码
  grep -n "createUniversalBinary\|isUniversal" setup.dart

═══════════════════════════════════════════════════════════════════════════════

✨ 特别提示：

  • 通用二进制文件体积约为单架构文件的 1.5-1.8 倍（正常现象）
  • 最终的 DMG 包因为压缩会显著缩小
  • 建议在不同架构的 Mac 上各测试一遍（Intel + Apple Silicon）
  • 完整构建首次需要下载依赖，较为耗时
  • 后续增量构建会快得多

═══════════════════════════════════════════════════════════════════════════════

版本：1.0.0 | 日期：2025/03/25 | 支持：macOS 10.15+

EOF

# 可选：自动启动构建
if [[ "$1" == "--auto" ]]; then
  echo ""
  echo "🏗️ 开始自动构建..."
  make macos_universal
fi
