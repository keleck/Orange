import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/app_colors.dart';

/// 移动端底部导航栏（带滑动效果）
///
/// 支持点击切换，也支持在导航栏上左右拖拽切换：
/// 拖拽时蓝色高亮块跟手移动、图标颜色随位移插值，松手后按位移/速度吸附到相邻 tab。
class MobileNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const MobileNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<MobileNavigationBar> createState() => _MobileNavigationBarState();
}

class _MobileNavigationBarState extends State<MobileNavigationBar> {
  static const int _itemCount = 3;
  static const Duration _slideDuration = Duration(milliseconds: 320);

  /// 拖拽中相对当前选中项的位移，单位为「档」
  double _dragFraction = 0;
  bool _dragging = false;

  double get _base => widget.selectedIndex.toDouble();

  /// 当前滑块位置（档，可为小数）
  double get _position =>
      (_base + _dragFraction).clamp(0.0, (_itemCount - 1).toDouble());

  void _handleDragUpdate(DragUpdateDetails details, double itemWidth) {
    if (itemWidth <= 0) {
      return;
    }
    setState(() {
      _dragging = true;
      _dragFraction = (_dragFraction + details.delta.dx / itemWidth)
          .clamp(-_base, _itemCount - 1 - _base)
          .toDouble();
    });
  }

  void _handleDragEnd(DragEndDetails details, double itemWidth) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    var steps = _dragFraction.round();
    // 轻扫一下也能换档
    if (steps == 0 && velocity.abs() > 320) {
      steps = velocity > 0 ? 1 : -1;
    }
    final target =
        (widget.selectedIndex + steps).clamp(0, _itemCount - 1).toInt();
    setState(() {
      _dragFraction = 0;
      _dragging = false;
    });
    if (target != widget.selectedIndex) {
      widget.onDestinationSelected(target);
    }
  }

  void _handleDragCancel() {
    setState(() {
      _dragFraction = 0;
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // 增加左右和底部边距，增强悬浮感
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 与滑块步进保持一致：三段等分（两侧各留 4 的余量）
          final itemWidth = (constraints.maxWidth - 8) / _itemCount;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) =>
                _handleDragUpdate(details, itemWidth),
            onHorizontalDragEnd: (details) => _handleDragEnd(details, itemWidth),
            onHorizontalDragCancel: _handleDragCancel,
            // 阴影必须画在 ClipRRect 外层，否则会被圆角裁掉
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.42)
                        : const Color(0xFF6B7F9B).withValues(alpha: 0.18),
                    blurRadius: isDark ? 22 : 26,
                    offset: const Offset(0, 6),
                    spreadRadius: isDark ? 0 : -1,
                  ),
                  // 近距离一层，避免边缘发虚
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.18)
                        : const Color(0xFF6B7F9B).withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24), // 增大圆角
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 增强毛玻璃效果
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surface(context, 0.08), // 降低不透明度，更透明
                          AppColors.surface(context, 0.03),
                        ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? AppColors.surface(context, 0.1)
                            : AppColors.outline(context),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: SizedBox(
                      height: 64, // 稍微增加高度
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: _base,
                          end: _position,
                        ),
                        duration:
                            _dragging ? Duration.zero : _slideDuration,
                        curve: Curves.easeOutCubic,
                        builder: (context, position, _) {
                          return Stack(
                            children: [
                              // 背景滑动条
                              _buildSlidingBackground(itemWidth, position),
                              // 导航项内容
                              _buildNavigationItems(
                                appLocalizations,
                                position,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建滑动背景
  Widget _buildSlidingBackground(double itemWidth, double position) {
    return Positioned.fill(
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(6), // 增加内边距
        child: Transform.translate(
          offset: Offset(position * itemWidth, 0),
          child: Container(
            width: itemWidth - 6, // 调整间隙
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade400.withValues(alpha: 0.9),
                  Colors.blue.shade600.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建导航项
  Widget _buildNavigationItems(
    AppLocalizations appLocalizations,
    double position,
  ) {
    return Row(
      children: [
        _buildNavItem(
          icon: Icons.home_rounded,
          label: appLocalizations.xboardHome,
          index: 0,
          position: position,
        ),
        _buildNavItem(
          icon: Icons.shopping_bag_rounded,
          label: appLocalizations.plans,
          index: 1,
          position: position,
        ),
        _buildNavItem(
          icon: Icons.person_rounded,
          label: AppLocalizations.of(context).xboardMine,
          index: 2,
          position: position,
        ),
      ],
    );
  }

  /// 构建单个导航项
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required double position,
  }) {
    final isSelected = widget.selectedIndex == index;

    // 计算当前索引与滑块位置的距离
    final distance = (position - index).abs();
    // 根据距离计算透明度和颜色
    final opacity = (1 - (distance * 0.4)).clamp(0.0, 1.0);
    final iconColor = Color.lerp(
      AppColors.fg(context).withValues(alpha: 0.4),
      AppColors.fg(context),
      opacity,
    )!;

    // 根据距离计算图标大小，防止在滑动时图标变大
    final scale = (1 - (distance * 0.15)).clamp(0.8, 1.0);
    final iconSize = 28 * scale;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            widget.onDestinationSelected(index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: iconColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
