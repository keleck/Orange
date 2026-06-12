# 🔐 配置加密 - 命令速查表

## 最常用的 3 个命令

### 1. 生成密钥
```bash
dart run lib/xboard/config/tools/encrypt_config.dart --generate-key
```

### 2. 加密配置
```bash
export XBOARD_CONFIG_KEY="你的密钥"
bash encrypt-config.sh
```

### 3. 构建应用
```bash
flutter build apk --release --dart-define=XBOARD_CONFIG_KEY=$XBOARD_CONFIG_KEY
```

---

## 完整命令参考

| 操作 | 命令 |
|------|------|
| **生成密钥** | `dart run lib/xboard/config/tools/encrypt_config.dart --generate-key` |
| **加密配置** | `export XBOARD_CONFIG_KEY=xxx && bash encrypt-config.sh` |
| **验证加密** | `ls -lh assets/config/xboard.config.bin` |
| **查看加密文件** | `head -c 100 assets/config/xboard.config.bin` |
| **删除加密文件** | `rm assets/config/xboard.config.bin` |
| **构建 APK** | `flutter build apk --dart-define=XBOARD_CONFIG_KEY=xxx` |
| **构建 IOS** | `flutter build ios --dart-define=XBOARD_CONFIG_KEY=xxx` |
| **构建 macOS** | `flutter build macos --dart-define=XBOARD_CONFIG_KEY=xxx` |
| **清理环境** | `unset XBOARD_CONFIG_KEY` |

---

## 开发工作流

```bash
# ① 生成密钥（首次）
KEY=$(dart run lib/xboard/config/tools/encrypt_config.dart --generate-key | tail -1)
echo "密钥: $KEY"

# ② 保存到环境
echo "export XBOARD_CONFIG_KEY='$KEY'" > .env
echo ".env" >> .gitignore

# ③ 后续使用
source .env
bash encrypt-config.sh

# ④ 构建应用
flutter build apk --release --dart-define=XBOARD_CONFIG_KEY=$XBOARD_CONFIG_KEY
```

---

## 故障排除命令

```bash
# 检查密钥是否设置
echo $XBOARD_CONFIG_KEY

# 检查源文件是否存在
ls -lh assets/config/xboard.config.yaml

# 检查加密文件是否生成
ls -lh assets/config/xboard.config.bin

# 查看脚本位置
which encrypt-config.sh

# 运行加密脚本（详细输出）
bash -x encrypt-config.sh
```

---

## CI/CD 命令

### GitHub Actions
```yaml
- name: Encrypt and Build
  env:
    XBOARD_CONFIG_KEY: ${{ secrets.XBOARD_CONFIG_KEY }}
  run: |
    bash encrypt-config.sh
    flutter build apk --dart-define=XBOARD_CONFIG_KEY=$XBOARD_CONFIG_KEY
```

### GitLab CI
```yaml
encrypt_and_build:
  script:
    - bash encrypt-config.sh
    - flutter build apk --dart-define=XBOARD_CONFIG_KEY=$XBOARD_CONFIG_KEY
  variables:
    XBOARD_CONFIG_KEY: $XBOARD_CONFIG_KEY
```

---

## 快速一行命令

```bash
# 一键生成、加密、构建
KEY=$(dart run lib/xboard/config/tools/encrypt_config.dart --generate-key | tail -1) && \
export XBOARD_CONFIG_KEY="$KEY" && \
bash encrypt-config.sh && \
flutter build apk --release --dart-define=XBOARD_CONFIG_KEY=$XBOARD_CONFIG_KEY
```

---

## 💡 提示

- 密钥不要硬编码到脚本里
- 使用环境变量安全传递密钥
- 将密钥存储在密码管理器中
- 不要将密钥提交到 Git
- 定期轮换密钥

