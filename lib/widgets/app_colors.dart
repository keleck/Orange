import 'package:flutter/material.dart';

/// 应用全局颜色配置
/// 统一管理所有页面的背景渐变颜色
class AppColors {
  AppColors._();

  // 渐变背景颜色 - 深色模式风格的紫色和海军蓝
  static const Color gradientColor1 = Color(0xFF1A0F2E); // 深紫色
  static const Color gradientColor2 = Color(0xFF0F1419); // 深紫黑
  static const Color gradientColor3 = Color(0xFF0F1419); // 深紫黑
  static const Color gradientColor4 = Color(0xFF1A0F2E); // 深紫色

  // 渐变停止点
  static const List<double> gradientStops = [0.0, 0.3, 0.7, 1.0];

  /// 获取标准的背景渐变
  static LinearGradient getBackgroundGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        gradientColor1,
        gradientColor2,
        gradientColor3,
        gradientColor4,
      ],
      stops: gradientStops,
    );
  }

  /// 获取背景渐变的BoxDecoration
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
