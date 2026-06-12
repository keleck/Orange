# URL 加密快速参考

## 🔐 演示密钥（开发环境）
```
CAoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJyg=
```

## 🔒 演示加密 URL（已验证）
```
zs/Q0dLT1NXW19jZ2tvc3WB+f3x+NCA/Y3NkOnJ/Y3t2fn4yfnFyD0pHT0FGTQhcY2JhemR+IGJwZTx5dH95N2t/dnNpezFDTkxFTUIITVtnZGh0dHBzOi8vcmF3LmdpdGNvZGUuY29tL2tlbGVjay90
```

## 🎯 三个关键文件

### 1. config_file_loader.dart
```dart
static const String encryptedRemoteUrl = 
  'zs/Q0dLT1NXW19jZ2tvc3WB+f3x+NCA/...';

static final List<RemoteSourceConfig> _builtInRemoteSources = [
  RemoteSourceConfig(
    name: 'redirect',
    url: encryptedRemoteUrl,
    isEncrypted: true,
  ),
];
```

### 2. main.dart
```dart
final encryptionKey = String.fromEnvironment(
  'URL_ENCRYPTION_KEY',
  defaultValue: 'CAoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJyg=',
);
ConfigFileLoader.setEncryptionKey(encryptionKey);
```

### 3. 构建命令
```bash
flutter build apk \
  --dart-define=URL_ENCRYPTION_KEY="CAoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJyg="
```

## ⚡ 常用命令

### 生成密钥
```bash
dart tools/encrypt_url.dart --generate-key
```

### 加密 URL
```bash
dart tools/encrypt_url.dart \
  --key "你的密钥" \
  --url "你的URL"
```

### 验证解密
```bash
dart tools/encrypt_url.dart \
  --key "你的密钥" \
  --decrypt "加密字符串"
```

## 📋 集成步骤检查表

- [x] 第 1 步：生成密钥 → `CAoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJyg=`
- [x] 第 2 步：加密 URL → `zs/Q0dLT1NXW19jZ2tvc3WB+f3x+NCA/...`
- [x] 第 3 步：更新 `config_file_loader.dart`
- [x] 第 4 步：更新 `main.dart`
- [x] 第 5 步：验证解密功能 → ✓ 通过
- [x] 第 6 步：构建命令准备好

## 🚀 部署

### 开发环境
```bash
flutter run --debug
```
应用启动时日志：`✓ URL 加密密钥已设置`

### 生产环境
```bash
# 使用 GitHub Secrets 或环境变量注入密钥
flutter build apk --dart-define=URL_ENCRYPTION_KEY=$SECRET_KEY --release
```

## 🔍 验证加密有效性

```bash
# 检查二进制中没有明文 URL
strings app.apk | grep "raw.gitcode"  # 应无结果

# 检查有加密字符串
strings app.apk | grep "zs/Q0dLT1NXW"  # 应有结果
```

## 📚 详细文档

- [完整演示](URL_ENCRYPTION_DEMO.md)
- [安全指南](CONFIG_REMOTE_SOURCES.md)
- [URL 加密工具](lib/xboard/config/utils/url_cipher.dart)
- [配置加载器](lib/xboard/config/utils/config_file_loader.dart)
