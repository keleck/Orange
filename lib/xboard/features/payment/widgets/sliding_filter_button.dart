import 'package:flutter/material.dart';
import 'package:fl_clash/widgets/app_colors.dart';

/// 带滑动效果的分类过滤按钮
class SlidingFilterButton extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  const SlidingFilterButton({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.labels,
  });

  @override
  State<SlidingFilterButton> createState() => _SlidingFilterButtonState();
}

class _SlidingFilterButtonState extends State<SlidingFilterButton>
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
  void didUpdateWidget(SlidingFilterButton oldWidget) {
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface(context, 0.08),
            AppColors.surface(context, 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: AppColors.fg(context).withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // 背景滑动条
              _buildSlidingBackground(),
              // 按钮本体
              _buildButtonContent(),
            ],
          );
        },
      ),
    );
  }

  /// 构建滑动背景
  Widget _buildSlidingBackground() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth - 4; // 减去左右padding（4+4）
          final itemWidth = totalWidth / widget.labels.length;

          return AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, _) {
              final offset = _slideAnimation.value * itemWidth;

              return Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(4),
                child: Transform.translate(
                  offset: Offset(offset, 0),
                  child: Container(
                    width: itemWidth - 4, // 减去左右间隙
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(45),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.2),
                          blurRadius: 6,
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

  /// 构建按钮内容
  Widget _buildButtonContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(widget.labels.length, (index) {
            final isSelected = widget.selectedIndex == index;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!isSelected) {
                    widget.onChanged(index);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, _) {
                        // 计算当前索引与目标索引的距离
                        final distance = (_slideAnimation.value - index).abs();
                        // 根据距离计算透明度和颜色
                        final opacity = (1 - (distance * 0.3)).clamp(0.0, 1.0);
                        final textColor = Color.lerp(
                          AppColors.fg(context).withValues(alpha: 0.6),
                          AppColors.fg(context),
                          opacity,
                        )!;

                        return Text(
                          widget.labels[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: textColor,
                            letterSpacing: isSelected ? 0.3 : 0,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
