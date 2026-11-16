import 'package:fl_clash/widgets/app_colors.dart';
import 'package:flutter/material.dart';

/// 圆润的开关（iOS 风格）
///
/// 轨道为胶囊形，滑块为比轨道略大的白色圆点并带柔和阴影，
/// 打开时轨道填充主题色。整体尺寸与 Material Switch 接近，
/// 替换时不会改变原有布局。
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.duration = const Duration(milliseconds: 200),
  });

  /// 当前是否打开
  final bool value;

  /// 为 null 时开关处于禁用态
  final ValueChanged<bool>? onChanged;

  /// 打开时的轨道颜色，默认取主题主色
  final Color? activeColor;

  /// 动画时长
  final Duration duration;

  /// 轨道宽度
  static const double _trackWidth = 50;

  /// 轨道高度
  static const double _trackHeight = 26;

  /// 滑块直径（比轨道高，形成轻微外凸）
  static const double _knobSize = 30;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final isDark = AppColors.isDark(context);
    final accent = activeColor ?? Theme.of(context).colorScheme.primary;
    final trackOffColor =
        isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFE7E8EC);
    final trackColor = value ? accent : trackOffColor;

    return Semantics(
      button: true,
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: SizedBox(
            width: _trackWidth,
            height: _knobSize,
            child: Stack(
              children: [
                // 轨道
                Center(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOut,
                    width: _trackWidth,
                    height: _trackHeight,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(_trackHeight / 2),
                    ),
                  ),
                ),
                // 滑块
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeOut,
                  left: value ? _trackWidth - _knobSize : 0,
                  top: 0,
                  width: _knobSize,
                  height: _knobSize,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.04),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.45 : 0.16),
                          blurRadius: 5,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
