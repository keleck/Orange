# Android 支付网关加载失败修复说明

## 问题描述
安卓点击支付时，支付网关会出现"加载支付页面失败"的错误。

## 根本原因
1. **网络安全配置缺失** - Android 9+ 默认禁止明文HTTP流量
2. **WebView混合内容限制** - HTTPS页面无法加载HTTP资源
3. **缺少Android WebView平台特定配置**
4. **错误处理不够精确** - 子资源错误也会导致页面显示失败

## 修复内容

### 1. AndroidManifest.xml 配置
添加了以下配置：
- `android:usesCleartextTraffic="true"` - 允许明文流量
- `android:networkSecurityConfig="@xml/network_security_config"` - 引用网络安全配置

### 2. 网络安全配置文件
创建 `android/app/src/main/res/xml/network_security_config.xml`：
- 允许所有明文流量（用于第三方支付网关）
- 信任系统和用户证书
- 配置本地开发域名

### 3. WebView 代码优化
在 `lib/xboard/features/payment/pages/payment_gateway_page.dart` 中：
- 设置WebView背景色为白色
- 启用缩放功能
- 改进错误处理，只在主资源失败时显示错误（忽略子资源错误）
- 添加导航请求处理，允许所有导航
- 添加详细的调试日志

### 4. 依赖说明
使用 `webview_flutter: ^4.13.0`，该版本已经内置了Android平台支持，无需额外添加 `webview_flutter_android` 依赖。

## 使用步骤

1. **安装依赖**
```bash
flutter pub get
```

2. **清理构建缓存**
```bash
cd android
./gradlew clean
cd ..
```

3. **重新构建应用**
```bash
flutter build apk --release
# 或者用于调试
flutter run
```

## 测试建议

1. 测试HTTP支付网关
2. 测试HTTPS支付网关
3. 测试混合内容（HTTPS页面加载HTTP资源）
4. 检查错误日志输出

## 注意事项

- 如果支付网关使用自签名证书，可能需要额外配置
- 生产环境建议限制明文流量仅用于特定域名
- 可以在 `network_security_config.xml` 中添加特定支付网关域名

## 调试日志

修复后的代码会输出详细的调试日志：
- `[PaymentGateway] 初始化 WebView` - WebView初始化
- `[PaymentGateway] 页面开始加载` - 页面加载开始
- `[PaymentGateway] 页面加载完成` - 页面加载成功
- `[PaymentGateway] WebView 资源错误` - 资源加载错误（区分主资源和子资源）
- `[PaymentGateway] 应用Android特定配置` - Android平台配置

使用 `flutter logs` 或 `adb logcat` 查看这些日志。
