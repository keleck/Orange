import 'dart:ui';

import 'package:flutter/material.dart';

/// 液态玻璃卡片。
///
/// 和普通白卡的区别：它用 [BackdropFilter] 真的把背后的内容模糊掉，
/// 再叠一层半透明白 + 顶部高光边，看起来像一块有厚度的玻璃，
/// 而不是一张贴在背景上的白纸。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 22,
    this.onTap,
    this.blur = 18,
    this.tint,
    this.darkFill = 0.08,
    this.darkBorder = 0.14,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;

  /// 背景模糊强度，越大越"磨砂"
  final double blur;

  /// 玻璃的染色（默认无色，只留白）
  final Color? tint;

  /// 夜间模式的填充透明度：夜间不套用白玻璃，沿用原来的半透明白
  final double darkFill;

  /// 夜间模式的描边透明度
  final double darkBorder;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? Colors.white;

    final glass = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // 白天：上亮下微沉的白色玻璃；夜间：沿用原来的半透明白，不做改动
            color: dark ? base.withValues(alpha: darkFill) : null,
            gradient: dark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      base.withValues(alpha: 0.78),
                      base.withValues(alpha: 0.56),
                    ],
                  ),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: dark ? darkBorder : 0.85,
              ),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        // 夜间不加阴影，保持原来的观感
        boxShadow: dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x140F1B2E),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Color(0x1F0F1B2E),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
      ),
      child: onTap == null
          ? glass
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: onTap,
                child: glass,
              ),
            ),
    );
  }
}
