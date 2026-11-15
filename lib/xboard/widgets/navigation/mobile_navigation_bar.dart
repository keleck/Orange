import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/widgets/app_colors.dart';

/// 移动端底部导航栏（带滑动效果）
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

class _MobileNavigationBarState extends State<MobileNavigationBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideAnimation = Tween<double>(
      begin: 0,
      end: widget.selectedIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void didUpdateWidget(MobileNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _slideAnimation = Tween<double>(
        begin: oldWidget.selectedIndex.toDouble(),
        end: widget.selectedIndex.toDouble(),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ));
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // 增加左右和底部边距，增强悬浮感
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
                  AppColors.fg(context).withValues(alpha: 0.08), // 降低不透明度，更透明
                  AppColors.fg(context).withValues(alpha: 0.03),
                ],
              ),
              border: Border.all(
                color: AppColors.fg(context).withValues(alpha: 0.1), // 降低边框不透明度
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                  blurRadius: 20, // 增强阴影
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SizedBox(
              height: 64, // 稍微增加高度
              child: Stack(
                children: [
                  // 背景滑动条
                  _buildSlidingBackground(),
                  // 导航项内容
                  _buildNavigationItems(appLocalizations),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建滑动背景
  Widget _buildSlidingBackground() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, _) {
              final totalWidth = constraints.maxWidth - 8; // 调整padding
              final itemWidth = totalWidth / 3;
              final offset = _slideAnimation.value * itemWidth;

              return Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(6), // 增加内边距
                child: Transform.translate(
                  offset: Offset(offset, 0),
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
              );
            },
          );
        },
      ),
    );
  }

  /// 构建导航项
  Widget _buildNavigationItems(AppLocalizations appLocalizations) {
    return Row(
      children: [
        _buildNavItem(
          icon: Icons.home_rounded,
          label: appLocalizations.xboardHome,
          index: 0,
        ),
        _buildNavItem(
          icon: Icons.shopping_bag_rounded,
          label: appLocalizations.plans,
          index: 1,
        ),
        _buildNavItem(
          icon: Icons.person_rounded,
          label: AppLocalizations.of(context).xboardMine,
          index: 2,
        ),
      ],
    );
  }

  /// 构建单个导航项
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = widget.selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            widget.onDestinationSelected(index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, _) {
            // 计算当前索引与目标索引的距离
            final distance = (_slideAnimation.value - index).abs();
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

            return SizedBox.expand(
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
            );
          },
        ),
      ),
    );
  }
}
