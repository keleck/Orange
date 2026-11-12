import 'package:flutter/material.dart';

/// 参考应用里的图标配色：每个功能一个固定色，实色圆角方块 + 白色图标
class AppIconColors {
  AppIconColors._();

  static const Color blue = Color(0xFF0A84FF);
  static const Color purple = Color(0xFF7C5CFF);
  static const Color green = Color(0xFF22C55E);
  static const Color pink = Color(0xFFFF2D55);
  static const Color magenta = Color(0xFFE619C8);
  static const Color teal = Color(0xFF00C2D1);
  static const Color orange = Color(0xFFFF9F0A);
  static const Color grey = Color(0xFF8E8E93);
}

/// 实色圆角方块图标（iOS 图标那种观感）
class AppIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  const AppIconTile({
    super.key,
    required this.icon,
    this.color = AppIconColors.blue,
    this.size = 44,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.14)!,
            color,
          ],
        ),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.5,
        color: Colors.white,
      ),
    );
  }
}
