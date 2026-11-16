import 'package:fl_clash/widgets/app_colors.dart';
import 'package:flutter/material.dart';

/// 统一开关样式
///
/// 与「我的钱包 - 自动续费」使用的开关保持一致：内部为 [Switch.adaptive]，
/// 在 iOS / macOS 上渲染成 Cupertino 样式（胶囊轨道 + 白色圆点），
/// 其他平台渲染成 Material 样式。
///
/// 关闭态轨道：白天浅灰、夜间半透明白；开启态轨道取 [activeColor]（默认主题主色）。
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  /// 当前是否打开
  final bool value;

  /// 为 null 时开关处于禁用态
  final ValueChanged<bool>? onChanged;

  /// 打开时的轨道颜色，默认取主题主色
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor ?? Theme.of(context).colorScheme.primary,
      // 滑块始终纯白（夜间也用白色，不要半透明灰）
      inactiveThumbColor: Colors.white,
      inactiveTrackColor:
          isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFC9CFD8),
    );
  }
}
