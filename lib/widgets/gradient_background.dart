import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 深色模式风格的紫色和海军蓝渐变背景
/// 提供大气、极简的深色背景效果
class GradientBackground extends StatelessWidget {
  final Widget child;
  final bool animated;

  const GradientBackground({
    super.key,
    required this.child,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppColors.getBackgroundDecoration(),
      child: child,
    );
  }
}

/// 带有微妙动画效果的渐变背景
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  AppColors.gradientColor1,
                  AppColors.animatedGradientColor1,
                  _controller.value * 0.3,
                )!,
                AppColors.gradientColor2,
                AppColors.gradientColor3,
                Color.lerp(
                  AppColors.gradientColor4,
                  AppColors.animatedGradientColor2,
                  _controller.value * 0.3,
                )!,
              ],
              stops: AppColors.gradientStops,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// 卡片或容器使用的局部渐变背景
class CardGradientBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const CardGradientBackground({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardGradientColor1.withValues(alpha: 0.6), // 半透明深紫
            AppColors.cardGradientColor2.withValues(alpha: 0.4), // 半透明海军蓝
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
