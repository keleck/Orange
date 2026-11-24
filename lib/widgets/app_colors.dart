import 'package:flutter/material.dart';

/// 应用全局颜色配置
/// 统一管理所有页面的背景渐变与前景色，同时支持深色 / 浅色两套主题
class AppColors {
  AppColors._();

  // ------------------------------------------------------------ 深色（夜间）
  static const Color gradientColor1 = Color(0xFF1A0F2E); // 深紫色
  static const Color gradientColor2 = Color(0xFF0F1419); // 深紫黑
  static const Color gradientColor3 = Color(0xFF0F1419); // 深紫黑
  static const Color gradientColor4 = Color(0xFF1A0F2E); // 深紫色

  // ------------------------------------------------------------ 浅色（白天）
  // 蓝白 + 光感：底色是一层极淡的冷蓝，左上角带一团柔光，
  // 卡片用半透明白（磨砂感），让光透上来形成层次，而不是靠描边硬切。
  static const Color lightSurface = Color(0xFFFFFFFF); // 卡片（不透明白，用于弹层）
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF); // 弹层
  static const Color lightSurfaceSubtle = Color(0xFFF4F8FE); // 卡片内次级块
  static const Color lightSurfaceStrong = Color(0xFFE8EFFA); // 嵌套块 / 输入框
  static const Color lightScaffold = Color(0xFFE7EFFA); // 页面底色（渐变深处）

  // 磨砂卡片：半透明白，让背景的光晕透上来
  static const Color lightGlass = Color(0xD9FFFFFF); // 85% 白

  // 背景：左上角柔光 → 右下角略深，形成斜向的光感
  static const Color lightGradientColor1 = Color(0xFFFCFDFF); // 光心
  static const Color lightGradientColor2 = Color(0xFFEDF4FD); // 过渡
  static const Color lightGradientColor3 = Color(0xFFE6EEF9); // 中段
  static const Color lightGradientColor4 = Color(0xFFE1EAF7); // 边缘

  static const List<double> gradientStops = [0.0, 0.3, 0.7, 1.0];

  /// 浅色主题下的前景色（文字 / 图标）
  static const Color lightForeground = Color(0xFF101E36);

  /// 次级文字（说明、副标题）
  static const Color lightForegroundSecondary = Color(0xFF6A7A94);

  /// 三级文字（占位、辅助信息）
  static const Color lightForegroundTertiary = Color(0xFF8A99B0);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// 自适应前景色：深色下为白，浅色下为近黑
  static Color fg(BuildContext context) =>
      isDark(context) ? Colors.white : lightForeground;

  /// 自适应前景色（已有 ThemeData 但无 context 时用）
  static Color fgOf(ThemeData theme) =>
      theme.brightness == Brightness.dark ? Colors.white : lightForeground;

  /// 自适应前景色（次级，带透明度）
  static Color fgSecondary(BuildContext context, [double alpha = 0.7]) =>
      fg(context).withValues(alpha: alpha);

  /// 自适应卡片底色：深色下半透明白，浅色下柔和白
  static Color card(BuildContext context, [double alpha = 0.1]) =>
      isDark(context) ? Colors.white.withValues(alpha: alpha) : lightSurface;

  /// 卡片渐变（跟随当前主题）：深色为深紫/海军蓝，浅色为柔和白/淡蓝
  static List<Color> cardGradientColors(BuildContext context, {Color? accent}) {
    final primary = accent ?? Theme.of(context).colorScheme.primary;
    if (isDark(context)) {
      return [
        Color.alphaBlend(primary.withValues(alpha: 0.12), gradientColor1),
        Color.alphaBlend(primary.withValues(alpha: 0.04), gradientColor2),
      ];
    }
    return [
      lightSurface,
      Color.alphaBlend(
          primary.withValues(alpha: 0.05), const Color(0xFFF3F7FD)),
    ];
  }

  /// 卡片 / 弹层背景：深色下半透明白，浅色下柔和白（不做透明叠加）
  static Color surface(BuildContext context, [double darkAlpha = 0.06]) =>
      isDark(context)
          ? Colors.white.withValues(alpha: darkAlpha)
          : lightGlass;

  /// 卡片内的次级块（图标块 / 小标签底）：夜间半透明白，白天浅灰
  static Color subtle(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.06)
      : lightSurfaceSubtle;

  /// 分割线：夜间半透明白，白天浅灰
  static Color divider(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0xFFE5EAF2);

  /// 细描边：夜间半透明白，白天浅灰
  static Color outline(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.14)
      : const Color(0xFFDCE3EE);

  /// 弹层 / 面板底色（跟随当前主题）
  static Color panel(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A1535) : lightSurfaceElevated;

  /// 获取背景渐变（跟随当前主题）
  static Gradient backgroundGradient(BuildContext context) {
    if (isDark(context)) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          gradientColor1,
          gradientColor2,
          gradientColor3,
          gradientColor4
        ],
        stops: gradientStops,
      );
    }
    // 左上角光心向外扩散，右下角最沉——斜向的光感
    return const RadialGradient(
      center: Alignment(-0.9, -1.0),
      radius: 1.65,
      colors: [
        lightGradientColor1,
        lightGradientColor2,
        lightGradientColor3,
        lightGradientColor4,
      ],
      stops: gradientStops,
    );
  }

  /// 获取背景渐变的 BoxDecoration（跟随当前主题）
  static BoxDecoration backgroundDecoration(BuildContext context) {
    return BoxDecoration(
      gradient: backgroundGradient(context),
    );
  }

  /// 兼容旧调用：固定深色渐变（新代码请用 [backgroundDecoration]）
  static LinearGradient getBackgroundGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [gradientColor1, gradientColor2, gradientColor3, gradientColor4],
      stops: gradientStops,
    );
  }

  /// 兼容旧调用：固定深色渐变（新代码请用 [backgroundDecoration]）
  static BoxDecoration getBackgroundDecoration() {
    return BoxDecoration(
      gradient: getBackgroundGradient(),
    );
  }

  // 动画渐变的辅助颜色
  static const Color animatedGradientColor1 = Color(0xFF2D1B4E);
  static const Color animatedGradientColor2 = Color(0xFF1E2A47);

  // 卡片渐变背景颜色
  static const Color cardGradientColor1 = Color(0xFF1A1535); // 半透明深紫
  static const Color cardGradientColor2 = Color(0xFF1E2A47); // 半透明海军蓝
}
