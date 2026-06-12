# Mihomo 内核更新指南

## 📦 更新到 v1.19.24

本指南将帮助你将 Mihomo 内核更新到 v1.19.24 版本，新增 **VLESS Reality + XHTTP** 支持。

---

## 🎯 更新内容

### 新增功能
- ✅ **VLESS Reality + XHTTP** 协议支持
- ✅ 更好的性能和稳定性
- ✅ 最新的安全修复

### 版本信息
- **目标版本**: v1.19.24
- **发布地址**: https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.24
- **当前内核**: Clash.Meta (FlClash fork)

---

## 🚀 快速更新

### 方法一：使用自动化脚本（推荐）

```bash
# 1. 赋予执行权限
chmod +x update_mihomo_core.sh

# 2. 运行更新脚本
./update_mihomo_core.sh
```

脚本会自动：
- 检查当前版本
- 添加 mihomo 官方远程源
- 拉取 v1.19.24 版本
- 创建备份分支
- 提供合并/变基选项

### 方法二：手动更新

```bash
# 1. 进入内核目录
cd core/Clash.Meta

# 2. 添加 mihomo 官方远程源
git remote add mihomo https://github.com/MetaCubeX/mihomo.git

# 3. 拉取最新版本
git fetch mihomo --tags

# 4. 创建备份分支
git branch backup-before-update

# 5. 合并新版本
git merge v1.19.24 -m "Update to mihomo v1.19.24 - Add VLESS Reality + XHTTP"

# 6. 返回项目根目录
cd ../..
```

---

## 🔧 更新策略选择

### 策略 1: 合并 (Merge) - 推荐
**适用场景**: 保留 FlClash 的所有修改，同时获得新功能

```bash
git merge v1.19.24 --no-edit
```

**优点**:
- 保留完整的提交历史
- 更容易追踪更改
- 冲突较少

**缺点**:
- 提交历史可能较复杂

### 策略 2: 变基 (Rebase)
**适用场景**: 希望保持线性的提交历史

```bash
git rebase v1.19.24
```

**优点**:
- 提交历史更清晰
- 更容易理解代码演进

**缺点**:
- 可能遇到更多冲突
- 需要更多手动处理

---

## 🛠️ 处理合并冲突

如果更新过程中遇到冲突：

### 1. 查看冲突文件
```bash
git status
# 或
git diff --name-only --diff-filter=U
```

### 2. 解决冲突
手动编辑冲突文件，查找并解决 `<<<<<<<`, `=======`, `>>>>>>>` 标记的部分

### 3. 标记为已解决
```bash
git add <冲突文件>
```

### 4. 完成合并
```bash
# 如果是 merge
git commit -m "Resolve merge conflicts for v1.19.24"

# 如果是 rebase
git rebase --continue
```

### 5. 放弃更新（如果需要）
```bash
# 如果是 merge
git merge --abort

# 如果是 rebase
git rebase --abort

# 恢复到备份分支
git checkout backup-before-update
```

---

## ✅ 验证更新

### 1. 检查版本信息
```bash
cd core/Clash.Meta
git log -1 --oneline
grep "^module" go.mod
```

### 2. 测试编译
```bash
cd core/Clash.Meta
go build
```

如果编译成功，说明更新没有破坏基本功能。

### 3. 检查 VLESS Reality + XHTTP 支持
```bash
# 搜索相关代码
grep -r "reality" --include="*.go" | head -5
grep -r "xhttp" --include="*.go" | head -5
```

---

## 🏗️ 重新构建应用

更新内核后，需要重新构建应用：

### Android
```bash
# ARM64 架构
make android_arm64

# 或完整应用
make android_app
```

### macOS
```bash
# 通用版本（Intel + Apple Silicon）
make macos_universal

# 或单独架构
make macos_arm64    # Apple Silicon
make macos_amd64    # Intel
```

### Windows
```bash
dart ./setup.dart windows
```

### Linux
```bash
dart ./setup.dart linux
```

---

## 📝 更新后的配置

### VLESS Reality 配置示例

```yaml
proxies:
  - name: "vless-reality"
    type: vless
    server: example.com
    port: 443
    uuid: your-uuid
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    reality-opts:
      public-key: your-public-key
      short-id: your-short-id
```

### XHTTP 配置示例

```yaml
proxies:
  - name: "vless-xhttp"
    type: vless
    server: example.com
    port: 443
    uuid: your-uuid
    network: xhttp
    tls: true
    xhttp-opts:
      host: example.com
      path: /path
```

---

## 🔍 常见问题

### Q1: 更新后编译失败
**A**: 检查 Go 版本是否满足要求（Go 1.20+）
```bash
go version
```

### Q2: 找不到 VLESS Reality 相关代码
**A**: 确认是否成功合并了 v1.19.24
```bash
cd core/Clash.Meta
git log --oneline | grep -i "reality\|xhttp"
```

### Q3: 应用运行异常
**A**: 尝试清理并重新构建
```bash
# 清理构建缓存
rm -rf build/ libclash/

# 重新构建
make android_arm64  # 或其他平台
```

### Q4: 想要回滚到旧版本
**A**: 使用备份分支
```bash
cd core/Clash.Meta
git checkout backup-before-update
cd ../..
# 重新构建应用
```

---

## 📚 相关资源

- [Mihomo 官方仓库](https://github.com/MetaCubeX/mihomo)
- [v1.19.24 发布说明](https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.24)
- [VLESS 协议文档](https://xtls.github.io/config/outbounds/vless.html)
- [Reality 协议说明](https://github.com/XTLS/REALITY)

---

## 🆘 获取帮助

如果遇到问题：

1. 查看 [Issues](https://github.com/hakimi-x/Xboard-Mihomo/issues)
2. 加入 [Telegram 群组](https://t.me/V2Hiidify)
3. 查看 Mihomo 官方文档

---

## 📋 更新检查清单

- [ ] 备份当前代码
- [ ] 运行更新脚本或手动更新
- [ ] 解决合并冲突（如有）
- [ ] 验证编译成功
- [ ] 重新构建应用
- [ ] 测试基本功能
- [ ] 测试 VLESS Reality + XHTTP
- [ ] 更新文档和配置示例

---

**更新日期**: 2025-01-XX  
**适用版本**: Mihomo v1.19.24  
**维护者**: Orange Team
