import 'dart:ui';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final List<Color>? gradientColors;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.color,
    this.gradientColors,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);
    final baseColor = color ?? theme.colorScheme.surface;

    // 白天：柔和白实色，不做模糊叠加，避免发灰；夜间：保持原来的玻璃质感
    final decoration = BoxDecoration(
      color: isDark
          ? baseColor.withValues(alpha: opacity)
          : AppColors.lightSurface,
      borderRadius: effectiveBorderRadius,
      border: border ??
          Border.all(
            color: theme.colorScheme.onSurface
                .withValues(alpha: isDark ? 0.1 : 0.06),
            width: 1,
          ),
      gradient: isDark
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors ??
                  [
                    baseColor.withValues(alpha: opacity + 0.1),
                    baseColor.withValues(alpha: opacity),
                  ],
            )
          : null,
      // 白天给柔和白卡片一层很淡的冷调阴影，拉开层次又不显脏
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: const Color(0xFF6B7F9B).withValues(alpha: 0.13),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
    );

    final inner = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: isDark
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: inner,
              )
            : inner,
      ),
    );
  }
}
