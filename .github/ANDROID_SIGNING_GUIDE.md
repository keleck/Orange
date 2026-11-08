# 🔐 Android 应用签名配置指南

## 📋 概述

为了在 GitHub Actions 中自动签名 Android 应用，需要配置签名密钥和相关信息。

## 🔑 步骤 1: 生成签名密钥（首次）

如果还没有签名密钥，使用以下命令生成：

```bash
keytool -genkey -v -keystore ~/fl-clash-upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

**回答提示信息：**
- 输入密钥库口令：（记住这个密码！）
- 再次输入新口令：（重复输入）
- 您的名字与姓氏是什么？例如：FL Clash Team
- 您的组织单位名称是什么？例如：Development
- 您的组织名称是什么？例如：FL Clash
- 其他信息可以按回车跳过

**重要：** 妥善保管生成的 `.jks` 文件和密码！

## 📝 步骤 2: 配置本地签名

### 2.1 创建 key.properties 文件

在 `android/` 目录下创建 `key.properties` 文件：

```bash
cd android
cat > key.properties << EOF
storePassword=你的密钥库密码
keyPassword=你的密钥密码
keyAlias=upload
storeFile=/Users/你的用户名/fl-clash-upload-keystore.jks
EOF
```

### 2.2 更新 .gitignore

确保 `android/.gitignore` 包含以下内容（避免提交密钥）：

```
key.properties
*.jks
*.keystore
```

### 2.3 配置 build.gradle.kts

编辑 `android/app/build.gradle.kts`，添加签名配置：

```kotlin
// 在文件顶部，导入部分之后
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... 其他配置 ...
    
    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                storeFile = file(keystoreProperties["storeFile"] ?: "")
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }
    
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            // ... 其他配置 ...
        }
    }
}
```

## 🚀 步骤 3: 配置 GitHub Actions

### 3.1 将密钥转换为 Base64

```bash
# macOS
base64 -i ~/fl-clash-upload-keystore.jks | pbcopy

# Linux
base64 ~/fl-clash-upload-keystore.jks | xclip -selection clipboard

# Windows (Git Bash)
cat ~/fl-clash-upload-keystore.jks | base64 | clip
```

### 3.2 在 GitHub 设置 Secrets

1. 访问你的 GitHub 仓库
2. 进入 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 依次添加以下 Secrets：

| 名称 | 值 | 说明 |
|------|------|------|
| `ANDROID_KEYSTORE_BASE64` | (粘贴刚才复制的 Base64 内容) | 密钥库文件的 Base64 编码 |
| `ANDROID_KEYSTORE_PASSWORD` | 你的密钥库密码 | 创建密钥时设置的 storePassword |
| `ANDROID_KEY_PASSWORD` | 你的密钥密码 | 创建密钥时设置的 keyPassword |
| `ANDROID_KEY_ALIAS` | `upload` | 密钥别名 |

## ✅ 步骤 4: 测试签名

### 本地测试

```bash
# 构建签名的 APK
flutter build apk --release

# 验证签名
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

### GitHub Actions 测试

1. 推送代码到 GitHub
2. 手动触发 "高级多平台打包" 工作流
3. 只选择 Android 平台
4. 查看构建日志，确认签名成功

## 🔍 验证签名信息

```bash
# 查看密钥库信息
keytool -list -v -keystore ~/fl-clash-upload-keystore.jks -alias upload

# 查看 APK 签名信息
keytool -printcert -jarfile app-release.apk
```

## 📱 Google Play 发布

如果需要上传到 Google Play Store：

### 选项 1: 使用 Play App Signing（推荐）

1. 首次上传时，Google Play 会要求注册 Play App Signing
2. 上传你的上传密钥证书（不是 .jks 文件）
3. 之后 Google 会管理应用签名密钥

### 选项 2: 自己管理签名密钥

需要额外创建一个用于发布的密钥，并在构建时使用。

## 🔄 密钥备份

**重要：** 签名密钥丢失将无法更新应用！

```bash
# 备份密钥到多个安全位置
cp ~/fl-clash-upload-keystore.jks ~/Dropbox/backups/
cp ~/fl-clash-upload-keystore.jks /path/to/external-drive/

# 或者使用加密工具
gpg -c ~/fl-clash-upload-keystore.jks
```

## 🛠️ 示例：完整的 build.gradle.kts

```kotlin
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 加载签名配置
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.follow.clash"
    compileSdk = 34
    
    defaultConfig {
        applicationId = "com.follow.clash"
        minSdk = 21
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }
    
    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                storeFile = file(keystoreProperties["storeFile"] ?: "")
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }
    
    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
        
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    
    kotlinOptions {
        jvmTarget = "1.8"
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
}
```

## ❗ 常见问题

### Q: 提示 "keytool: command not found"
A: 确保已安装 Java JDK，并配置了环境变量。

### Q: GitHub Actions 构建失败，提示签名错误
A: 检查以下几点：
- Secrets 是否正确配置
- Base64 编码是否完整（没有换行符）
- 密码是否正确

### Q: APK 无法安装，提示签名冲突
A: 卸载旧版本后重新安装，或使用相同的签名密钥。

### Q: 如何更换签名密钥？
A: 
- 如果使用 Play App Signing：可以更换上传密钥
- 如果自己管理：无法更换，否则无法升级应用

## 📚 参考资料

- [Flutter Android 部署文档](https://docs.flutter.dev/deployment/android)
- [Android 应用签名](https://developer.android.com/studio/publish/app-signing)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)

---

💡 **提示**: 签名密钥关系到应用的长期维护，务必妥善保管！
