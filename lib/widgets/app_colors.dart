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
  static const Color lightScaffold = Color(0xFFEDF2FB); // 页面底色（极光中段）

  // 磨砂卡片：半透明白，让背景的光晕透上来
  static const Color lightGlass = Color(0xA8FFFFFF); // 66% 白，玻璃卡（能透出背景）

  // 背景：左上角柔光 → 右下角略深，形成斜向的光感
  static const Color lightGradientColor1 = Color(0xFFF9FCFF); // 左下光心
  static const Color lightGradientColor2 = Color(0xFFE9F1FC); // 过渡
  static const Color lightGradientColor3 = Color(0xFFDEE8F6); // 中段最沉
  static const Color lightGradientColor4 = Color(0xFFFBFDFF); // 右上光心

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
  /// 列表分隔线 / 输入框描边：要看得见，不能用白色
  static Color separator(BuildContext context) => divider(context);

  static Color divider(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0xFFC0C9D6);

  /// 玻璃卡描边：白天用白色高光边，夜间用半透明白
  static Color glassBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.white.withValues(alpha: 0.85);

  /// 细描边：夜间半透明白，白天浅灰
  static Color outline(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.14)
      : const Color(0xFFDCE3EE);

  /// 卡片柔和阴影：浅色下用双层投影（贴近 + 扩散），营造浮起感
  static List<BoxShadow> cardShadow(BuildContext context) {
    if (isDark(context)) {
      return const [];
    }
    return const [
      BoxShadow(
        color: Color(0x1A12203A),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
      BoxShadow(
        color: Color(0x2412203A),
        blurRadius: 26,
        offset: Offset(0, 12),
      ),
    ];
  }

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
    // 双光晕：左下 + 右上两处偏亮，中间最沉。
    // BoxDecoration 只能挂一个 gradient，所以用一条对角渐变模拟「两团柔光」：
    // 两端亮、中段暗，视觉上就是两处光源。真正的径向双光晕需要包一层
    // Stack 叠两个 RadialGradient，那要改页面结构，暂不做。
    return const LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        lightGradientColor1, // 左下光
        lightGradientColor2,
        lightGradientColor3, // 中段最沉
        lightGradientColor2,
        lightGradientColor4, // 右上光
      ],
      stops: [0.0, 0.26, 0.5, 0.74, 1.0],
    );
  }

  /// 获取背景装饰（跟随当前主题）
  ///
  /// 白天用「底色 + 右上光晕 + 左下光晕」三层叠加，做出真正的双光晕；
  /// 夜晚保持原来的四段线性渐变。
  static Decoration backgroundDecoration(BuildContext context) {
    if (isDark(context)) {
      return MultiGradientDecoration([backgroundGradient(context)]);
    }
    // 极光：蓝 → 青 → 淡紫 斜向流动，顶部再压一层白光
    return const MultiGradientDecoration([
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE9F2FE), // 淡蓝
          Color(0xFFE4F4F2), // 青
          Color(0xFFEDE9FA), // 淡紫
        ],
        stops: [0.0, 0.45, 1.0],
      ),
      RadialGradient(
        center: Alignment(0.0, -1.0),
        radius: 0.85,
        colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 1.0],
      ),
    ]);
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


/// 多层渐变装饰。
///
/// Flutter 的 [BoxDecoration] 只能挂一个 gradient，做不出「底色 + 两团光晕」
/// 这种多光源背景。这里自己实现一个 [Decoration]，按顺序把多层渐变画在
/// 同一个矩形上，外层用透明到透明的径向渐变就能叠出柔光。
class MultiGradientDecoration extends Decoration {
  const MultiGradientDecoration(this.layers);

  final List<Gradient> layers;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _MultiGradientPainter(layers);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! MultiGradientDecoration ||
        other.layers.length != layers.length) {
      return false;
    }
    for (var i = 0; i < layers.length; i++) {
      if (other.layers[i] != layers[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(layers);
}

class _MultiGradientPainter extends BoxPainter {
  _MultiGradientPainter(this.layers);

  final List<Gradient> layers;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) {
      return;
    }
    final rect = offset & size;
    for (final layer in layers) {
      canvas.drawRect(rect, Paint()..shader = layer.createShader(rect));
    }
  }
}
