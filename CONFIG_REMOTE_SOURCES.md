# 远程配置源管理（安全指南）

## 概述

为了防止敏感的远程配置源 URL 在源代码或配置文件中暴露，我们采取了以下安全措施：

1. **YAML 配置文件隐藏**：`assets/config/xboard.config.yaml` 中的远程源配置项已清空
2. **客户端内嵌配置**：敏感 URL 打包到应用代码中
3. **URL 加密混淆**：使用 XOR + HMAC-SHA256 对 URL 进行加密，防止反编译直接暴露
4. **灵活部署机制**：支持构建时注入或运行时环境变量配置

## 文件说明

### 配置文件位置
- **YAML 配置文件**：`assets/config/xboard.config.yaml`
- **URL 加密工具**：`lib/xboard/config/utils/url_cipher.dart`
- **配置加载器**：`lib/xboard/config/utils/config_file_loader.dart`
- **配置数据类**：`lib/xboard/config/core/config_settings.dart`
- **加密脚本**：`tools/encrypt_url.dart`

## 安全架构

```
应用启动
  ↓
loadFromFile()
  ↓
YAML 中的远程源为空？
  ├─ 是 → 使用 _builtInRemoteSources
  │        ├─ URL 未加密？直接使用
  │        └─ URL 已加密？
  │           ├─ 检查加密密钥
  │           ├─ 解密 URL（XOR + HMAC）
  │           └─ 使用明文 URL
  └─ 否 → 使用 YAML 中的配置（仅限开发）
  ↓
应用初始化完成
```

## URL 加密方案

### 加密算法
- **对称加密**：XOR（带密钥轮换）
- **消息认证**：HMAC-SHA256 签名防篡改
- **编码格式**：Base64（便于在代码中使用）
- **可升级**：支持后续升级为 AES-256-CBC 等更强算法

### 加密流程

```
明文 URL
  ↓
生成随机 IV（16 字节）
  ↓
计算 HMAC-SHA256 签名
  ↓
使用密钥进行 XOR 加密：
  - 加密 URL 内容
  - 加密 HMAC 签名
  ↓
组合：IV + EncryptedUrl + EncryptedSignature
  ↓
Base64 编码
  ↓
加密字符串（可以安全地内嵌在代码中）
```

## 部署方案

### 方案 A：使用加密 URL（推荐用于生产）

#### 第 1 步：生成加密密钥

```bash
dart tools/encrypt_url.dart --generate-key
```

#### 第 2 步：加密敏感 URL

```bash
dart tools/encrypt_url.dart \
  --key "your_generated_key" \
  --url "https://raw.gitcode.com/keleck/tkhjvip/raw/main/remote.config.json"
```

#### 第 3 步：集成加密 URL 到代码

编辑 `lib/xboard/config/utils/config_file_loader.dart`：

```dart
static final List<RemoteSourceConfig> _builtInRemoteSources = [
  RemoteSourceConfig(
    name: 'redirect',
    url: 'encrypted_base64_string_here',
    priority: 100,
    isEncrypted: true,
  ),
];
```

#### 第 4 步：在应用启动时设置加密密钥

```dart
void main() {
  final encryptionKey = String.fromEnvironment(
    'URL_ENCRYPTION_KEY',
    defaultValue: 'your_key_here',
  );
  ConfigFileLoader.setEncryptionKey(encryptionKey);
  runApp(const MyApp());
}
```

#### 第 5 步：构建时注入密钥

```bash
flutter build apk \
  --dart-define=URL_ENCRYPTION_KEY="your_key_here"
```

### 方案 B：运行时从安全存储读取

使用 `flutter_secure_storage` 包：

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void initializeConfig() async {
  const storage = FlutterSecureStorage();
  final key = await storage.read(key: 'url_encryption_key');
  
  if (key != null) {
    ConfigFileLoader.setEncryptionKey(key);
  }
}
```

### 方案 C：YAML 配置（仅开发环境）

编辑 `assets/config/xboard.config.yaml`：

```yaml
xboard:
  provider: mihomo
  remote_config:
    sources:
      - name: development
        url: http://localhost:8080/config.json
        priority: 100
```

## 命令行工具使用

### 生成密钥

```bash
dart tools/encrypt_url.dart --generate-key
```

### 加密 URL

```bash
dart tools/encrypt_url.dart \
  --key "your_base64_key" \
  --url "https://example.com/config.json"
```

### 解密验证

```bash
dart tools/encrypt_url.dart \
  --key "your_base64_key" \
  --decrypt "encrypted_string"
```

## 安全最佳实践

1. **密钥管理**
   - 永远不要在代码中硬编码加密密钥
   - 使用环境变量或密钥管理服务
   - 定期轮换密钥（建议每 3-6 个月）

2. **防止 URL 暴露**
   - 确保 `.gitignore` 包含敏感文件
   - 使用 git-secrets 预防密钥提交
   - 定期审计 git 历史

3. **CI/CD 安全**
   - 使用 GitHub/GitLab 密钥管理功能
   - 避免在日志中打印密钥
   - 使用签名验证构建产物

4. **代码审计**
   - 检查反编译输出是否包含明文 URL
   - 使用静态分析工具检测硬编码密钥
   - 定期更新依赖

## 验证加密有效性

### 检查编译后的 APK

```bash
# 检查是否有暴露的明文 URL
strings app.apk | grep -i "raw.gitcode"
# 应该没有结果

# 检查加密的 Base64 字符串
strings app.apk | grep -E "^[A-Za-z0-9+/]{50,}"
```

### 验证解密功能

```dart
final plainUrl = "https://raw.gitcode.com/...";
final encryptionKey = "your_key";

// 加密
final encrypted = UrlCipher.encryptUrl(plainUrl, encryptionKey: encryptionKey);

// 解密
final decrypted = UrlCipher.decryptUrl(encrypted, encryptionKey: encryptionKey);

assert(decrypted == plainUrl);
```

## CI/CD 集成示例

### GitHub Actions

```yaml
name: Build Encrypted Release APK

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
      
      - name: Build APK
        env:
          URL_ENCRYPTION_KEY: ${{ secrets.URL_ENCRYPTION_KEY }}
        run: |
          flutter build apk \
            --dart-define=URL_ENCRYPTION_KEY=$URL_ENCRYPTION_KEY \
            --release
      
      - name: Verify encryption
        run: |
          if strings build/app/outputs/apk/release/app-release.apk | grep "raw.gitcode"; then
            echo "❌ 明文 URL 被发现，构建失败"
            exit 1
          fi
```

## 常见问题

**Q: 为什么要加密 URL？**
A: 防止反编译直接暴露敏感的后端服务器地址。虽然加密 URL 仍可通过高级逆向获得，但增加了攻击难度。

**Q: 解密后的 URL 是否仍然安全？**
A: 解密后的 URL 会在内存中存在。对于极高安全需求，可结合 TLS 证书固定和 API 签名验证。

**Q: 是否支持更强的加密算法？**
A: 当前使用 XOR + HMAC-SHA256。可升级为 AES-256-CBC，参见 `url_cipher.dart` 的注释。

**Q: 密钥泄露如何处理？**
A: 生成新密钥，重新加密所有 URL，发布新版本应用。可考虑多密钥支持以实现无缝过渡。

## 相关文件

- [URL 加密工具](lib/xboard/config/utils/url_cipher.dart)
- [配置加载器](lib/xboard/config/utils/config_file_loader.dart)
- [配置数据模型](lib/xboard/config/core/config_settings.dart)
- [加密脚本](tools/encrypt_url.dart)
