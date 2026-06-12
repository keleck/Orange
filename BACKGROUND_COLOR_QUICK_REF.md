# 背景颜色统一配置 - 快速参考

## 📋 概述
所有页面的背景颜色已统一使用 `AppColors` 配置，确保全局一致性。

## 🎨 如何修改背景颜色

### 方法：只需编辑一个文件
打开 `lib/widgets/app_colors.dart`，修改以下颜色值：

```dart
class AppColors {
  // 修改这4个颜色值即可影响所有页面
  static const Color gradientColor1 = Color(0xFF1A0F2E); // 深紫色 ← 改这里
  static const Color gradientColor2 = Color(0xFF0F1419); // 深紫黑 ← 改这里
  static const Color gradientColor3 = Color(0xFF0A1628); // 深海军蓝 ← 改这里
  static const Color gradientColor4 = Color(0xFF0D1B2A); // 海军蓝 ← 改这里
}
```

### 示例：更换为蓝色系渐变
```dart
static const Color gradientColor1 = Color(0xFF0F2027); // 深蓝黑
static const Color gradientColor2 = Color(0xFF203A43); // 深青蓝
static const Color gradientColor3 = Color(0xFF2C5364); // 青蓝
static const Color gradientColor4 = Color(0xFF0F2027); // 深蓝黑
```

### 示例：更换为绿色系渐变
```dart
static const Color gradientColor1 = Color(0xFF0F2027); // 深绿黑
static const Color gradientColor2 = Color(0xFF134E4A); // 深青绿
static const Color gradientColor3 = Color(0xFF065F46); // 绿色
static const Color gradientColor4 = Color(0xFF064E3B); // 深绿
```

## 📝 新页面如何使用

### 方式1：使用 BoxDecoration（推荐）
```dart
Container(
  decoration: AppColors.getBackgroundDecoration(),
  child: YourContent(),
)
```

### 方式2：只使用渐变
```dart
Container(
  decoration: BoxDecoration(
    gradient: AppColors.getBackgroundGradient(),
    // 可以添加其他装饰属性
    borderRadius: BorderRadius.circular(16),
  ),
  child: YourContent(),
)
```

### 方式3：使用 GradientBackground 组件
```dart
import 'package:fl_clash/widgets/gradient_background.dart';

GradientBackground(
  child: YourContent(),
)
```

## 🔍 已更新的页面（20个）

### 核心组件
- ✅ gradient_background.dart
- ✅ scaffold.dart
- ✅ routes.dart

### 用户相关
- ✅ settings_page.dart
- ✅ wallet_page.dart
- ✅ user_center_page.dart

### 认证
- ✅ login_page.dart
- ✅ register_page.dart
- ✅ forgot_password_page.dart

### 订阅和支付
- ✅ xboard_home_page.dart
- ✅ plans.dart
- ✅ plan_purchase_page.dart

### 工单
- ✅ tickets_page.dart
- ✅ create_ticket_page.dart

### 其他
- ✅ notice_list_page.dart
- ✅ invite_page.dart
- ✅ node_selector_page.dart
- ✅ traffic_log_page.dart
- ✅ order_page.dart
- ✅ notice_banner.dart

## ⚠️ 注意事项

1. **不要硬编码颜色值**
   ```dart
   // ❌ 错误做法
   Color(0xFF1A0F2E)
   
   // ✅ 正确做法
   AppColors.gradientColor1
   ```

2. **阴影颜色也要使用 AppColors**
   ```dart
   // ❌ 错误做法
   color: const Color(0xFF1A0F2E).withValues(alpha: 0.6)
   
   // ✅ 正确做法
   color: AppColors.gradientColor1.withValues(alpha: 0.6)
   ```

3. **记得导入**
   ```dart
   import 'package:fl_clash/widgets/app_colors.dart';
   ```

## 🚀 优势

- ✅ **一处修改，全局生效** - 只需改 app_colors.dart
- ✅ **避免遗漏** - 所有页面使用统一配置
- ✅ **易于维护** - 代码更简洁
- ✅ **类型安全** - 编译时检查

## 📞 需要帮助？

如果需要：
- 添加新的颜色主题
- 实现主题切换功能
- 自定义特定页面的颜色

请参考 `BACKGROUND_COLOR_UNIFICATION.md` 获取详细信息。
