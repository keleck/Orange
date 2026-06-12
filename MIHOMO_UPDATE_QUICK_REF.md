# Mihomo v1.19.24 更新快速参考

## 🚀 一键更新

```bash
chmod +x update_mihomo_core.sh
./update_mihomo_core.sh
```

---

## 📋 手动更新步骤

```bash
# 1. 进入内核目录
cd core/Clash.Meta

# 2. 添加远程源
git remote add mihomo https://github.com/MetaCubeX/mihomo.git

# 3. 拉取版本
git fetch mihomo --tags

# 4. 备份
git branch backup-$(date +%Y%m%d)

# 5. 合并
git merge v1.19.24 -m "Update to v1.19.24"

# 6. 返回
cd ../..
```

---

## 🔧 重新构建

```bash
# Android
make android_arm64

# macOS
make macos_universal

# Windows
dart ./setup.dart windows

# Linux
dart ./setup.dart linux
```

---

## 📝 VLESS Reality 配置

```yaml
proxies:
  - name: "Reality"
    type: vless
    server: example.com
    port: 443
    uuid: your-uuid
    network: tcp
    tls: true
    flow: xtls-rprx-vision
    reality-opts:
      public-key: your-public-key
      short-id: your-short-id
      server-name: www.microsoft.com
```

---

## 📝 XHTTP 配置

```yaml
proxies:
  - name: "XHTTP"
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

## 🆘 冲突解决

```bash
# 查看冲突
git status

# 解决后
git add .
git commit -m "Resolve conflicts"

# 或放弃
git merge --abort
```

---

## 🔙 回滚

```bash
cd core/Clash.Meta
git checkout backup-YYYYMMDD
cd ../..
make android_arm64  # 重新构建
```

---

## 📚 详细文档

- `MIHOMO_UPDATE_GUIDE.md` - 完整更新指南
- `VLESS_REALITY_XHTTP_GUIDE.md` - 协议配置指南
- https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.24
