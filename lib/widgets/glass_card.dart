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

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final base = tint ?? Colors.white;

    final glass = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // 上亮下微沉：模拟光从上方穿过玻璃
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base.withValues(alpha: 0.78),
                base.withValues(alpha: 0.56),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
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
        boxShadow: const [
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
