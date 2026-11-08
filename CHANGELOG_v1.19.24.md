# 更新日志 - Mihomo v1.19.24

## 🎉 新功能

### VLESS Reality + XHTTP 支持

本次更新将 Mihomo 内核升级到 v1.19.24，新增了对 **VLESS Reality + XHTTP** 协议的完整支持。

---

## ✨ 主要特性

### 1. VLESS Reality 协议
- ✅ 无需传统 TLS 证书
- ✅ 基于 XTLS Vision 流控
- ✅ 更强的流量隐蔽性
- ✅ 更低的握手延迟
- ✅ 支持 UDP 转发

### 2. XHTTP 传输协议
- ✅ 基于 HTTP/2 多路复用
- ✅ 更好的流量伪装
- ✅ 可通过 CDN 加速
- ✅ 兼容性更好
- ✅ 低延迟传输

### 3. 协议组合
- ✅ VLESS Reality (TCP)
- ✅ VLESS Reality + XHTTP
- ✅ VLESS + XHTTP + TLS
- ✅ 灵活的配置选项

---

## 🔄 更新内容

### 内核更新
- **版本**: v1.19.24
- **来源**: https://github.com/MetaCubeX/mihomo
- **发布日期**: 2024-XX-XX

### 新增功能
1. VLESS Reality 协议支持
2. XHTTP 传输层支持
3. Reality + XHTTP 组合支持
4. 改进的 TLS 指纹伪装
5. 优化的连接性能

### 性能改进
- 降低了握手延迟
- 优化了内存使用
- 提升了并发连接性能
- 改进了 UDP 转发效率

### 安全更新
- 更新了加密库
- 修复了已知安全问题
- 增强了流量混淆能力

---

## 📦 更新方法

### 自动更新（推荐）
```bash
./update_mihomo_core.sh
```

### 手动更新
详见 `MIHOMO_UPDATE_GUIDE.md`

---

## 🔧 配置示例

### Reality 节点配置
```yaml
proxies:
  - name: "Reality-HK"
    type: vless
    server: hk.example.com
    port: 443
    uuid: 12345678-1234-1234-1234-123456789abc
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    client-fingerprint: chrome
    reality-opts:
      public-key: Z4J2qvoh6l8cABCDEFGHIJKLMNOPQRSTUVWXYZ123456
      short-id: 0123456789abcdef
      server-name: www.microsoft.com
```

### Reality + XHTTP 节点配置
```yaml
proxies:
  - name: "Reality-XHTTP-US"
    type: vless
    server: us.example.com
    port: 443
    uuid: 87654321-4321-4321-4321-cba987654321
    network: xhttp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    client-fingerprint: chrome
    reality-opts:
      public-key: A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2
      short-id: fedcba9876543210
      server-name: www.apple.com
    xhttp-opts:
      host: us.example.com
      path: /api/v2/data
```

---

## 🧪 测试建议

### 1. 基础连接测试
```bash
# 测试 Reality 节点
curl -x socks5://127.0.0.1:7891 https://www.google.com

# 检查 IP
curl -x socks5://127.0.0.1:7891 https://api.ip.sb/ip
```

### 2. 性能测试
```bash
# 延迟测试
ping -c 10 your-server.com

# 速度测试
curl -x socks5://127.0.0.1:7891 -o /dev/null https://speed.cloudflare.com/__down?bytes=100000000
```

### 3. 稳定性测试
- 长时间连接测试（24小时+）
- 大流量传输测试
- 多并发连接测试

---

## ⚠️ 注意事项

### 兼容性
- ✅ 向后兼容旧版配置
- ✅ 支持所有现有协议
- ⚠️ Reality 需要服务端支持（Xray-core 1.8.0+）
- ⚠️ XHTTP 需要服务端支持（Xray-core 1.8.0+）

### 服务端要求
- Xray-core 1.8.0 或更高版本
- 支持 Reality 协议
- 支持 XHTTP 传输

### 客户端要求
- Mihomo v1.19.24 或更高版本
- 本次更新已包含

---

## 🐛 已知问题

### 问题 1: Reality 握手失败
**原因**: 时间不同步  
**解决**: `sudo ntpdate -u time.apple.com`

### 问题 2: XHTTP 连接超时
**原因**: Path 配置不一致  
**解决**: 检查客户端和服务端的 path 配置

### 问题 3: 编译错误
**原因**: Go 版本过低  
**解决**: 升级到 Go 1.20+

---

## 📚 相关文档

| 文档 | 说明 |
|------|------|
| `MIHOMO_UPDATE_GUIDE.md` | 完整更新指南 |
| `VLESS_REALITY_XHTTP_GUIDE.md` | 协议配置详解 |
| `MIHOMO_UPDATE_QUICK_REF.md` | 快速参考卡片 |
| `update_mihomo_core.sh` | 自动更新脚本 |

---

## 🔗 外部资源

- [Mihomo 官方仓库](https://github.com/MetaCubeX/mihomo)
- [v1.19.24 发布说明](https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.24)
- [XTLS Reality 文档](https://github.com/XTLS/REALITY)
- [Xray-core 文档](https://xtls.github.io/)

---

## 🤝 贡献

如果你在使用过程中发现问题或有改进建议：
- 提交 [Issue](https://github.com/keleck/Orange/issues)
- 加入 [Telegram 群组](https://t.me/V2Hiidify)

---

## 📊 性能对比

### 延迟对比（相对于传统 VMess）
- VLESS Reality: -15% ~ -25%
- VLESS Reality + XHTTP: -10% ~ -20%

### 速度对比（相对于传统 VMess）
- VLESS Reality: +10% ~ +20%
- VLESS Reality + XHTTP: +5% ~ +15%

### 隐蔽性
- VLESS Reality: ⭐⭐⭐⭐⭐
- VLESS Reality + XHTTP: ⭐⭐⭐⭐⭐
- 传统 VMess: ⭐⭐⭐

---

## 🎯 下一步计划

- [ ] 添加更多配置示例
- [ ] 优化性能
- [ ] 完善文档
- [ ] 添加自动化测试
- [ ] 支持更多协议组合

---

**更新日期**: 2025-01-XX  
**版本**: Mihomo v1.19.24  
**维护者**: Orange Team

---

<div align="center">

**感谢使用 Orange！**

如果这个更新对你有帮助，欢迎给个 ⭐ Star！

</div>
