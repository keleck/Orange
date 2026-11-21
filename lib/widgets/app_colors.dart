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
  // 白天不再使用纯白 #FFFFFF：大面积纯白在亮环境下刺眼、边缘发灰。
  // 统一改成带一丝冷调的「柔和白」，并保留由低到高的层级差异。
  static const Color lightSurface = Color(0xFFF8FAFC); // 卡片 / 面板主底色
  static const Color lightSurfaceElevated = Color(0xFFFBFCFE); // 弹层 / 浮起卡片
  static const Color lightSurfaceSubtle = Color(0xFFF1F5F9); // 卡片内次级块
  static const Color lightSurfaceStrong = Color(0xFFE9EFF6); // 嵌套块 / 输入框
  static const Color lightScaffold = Color(0xFFEDF3FD); // 页面底色（渐变中段）

  static const Color lightGradientColor1 = Color(0xFFDCEAFB); // 顶部淡蓝
  static const Color lightGradientColor2 = Color(0xFFE8F1FD); // 中上部
  static const Color lightGradientColor3 = Color(0xFFEFF5FE); // 中下部
  static const Color lightGradientColor4 = Color(0xFFE3EDFA); // 底部回蓝

  static const List<double> gradientStops = [0.0, 0.3, 0.7, 1.0];

  /// 浅色主题下的前景色（文字 / 图标）
  static const Color lightForeground = Color(0xFF1B1B1F);

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
          : lightSurface;

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
  static LinearGradient backgroundGradient(BuildContext context) {
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
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
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
