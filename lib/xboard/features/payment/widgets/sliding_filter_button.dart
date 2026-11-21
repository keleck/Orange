import 'package:flutter/material.dart';
import 'package:fl_clash/widgets/app_colors.dart';

/// 带滑动效果的分类过滤按钮
///
/// 支持点击切换，也支持在轨道上左右拖拽切换：
/// 拖拽时蓝色滑块跟手移动、文字颜色随位移插值，松手后按位移/速度吸附到相邻档位。
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

class _SlidingFilterButtonState extends State<SlidingFilterButton> {
  static const Duration _slideDuration = Duration(milliseconds: 300);

  /// 拖拽中相对当前选中项的位移，单位为「档」
  double _dragFraction = 0;
  bool _dragging = false;

  int get _count => widget.labels.length;

  double get _base => widget.selectedIndex.toDouble();

  /// 当前滑块位置（档，可为小数）
  double get _position =>
      (_base + _dragFraction).clamp(0.0, (_count - 1).toDouble());

  void _handleDragUpdate(DragUpdateDetails details, double itemWidth) {
    if (itemWidth <= 0) {
      return;
    }
    setState(() {
      _dragging = true;
      _dragFraction = (_dragFraction + details.delta.dx / itemWidth)
          .clamp(-_base, _count - 1 - _base)
          .toDouble();
    });
  }

  void _handleDragEnd(DragEndDetails details, double itemWidth) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    var steps = _dragFraction.round();
    // 轻扫一下也能换档
    if (steps == 0 && velocity.abs() > 260) {
      steps = velocity > 0 ? 1 : -1;
    }
    final target = (widget.selectedIndex + steps).clamp(0, _count - 1).toInt();
    setState(() {
      _dragFraction = 0;
      _dragging = false;
    });
    if (target != widget.selectedIndex) {
      widget.onChanged(target);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 外层 padding 4 + 滑块内 padding 4，两侧共让出 8
        final itemWidth = (constraints.maxWidth - 12) / _count;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              _handleDragUpdate(details, itemWidth),
          onHorizontalDragEnd: (details) => _handleDragEnd(details, itemWidth),
          onHorizontalDragCancel: _handleDragCancel,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surface(context, 0.08),
                  AppColors.surface(context, 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: AppColors.surface(context, 0.15),
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
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: _base, end: _position),
              duration: _dragging ? Duration.zero : _slideDuration,
              curve: Curves.easeOutCubic,
              builder: (context, position, _) {
                return Stack(
                  children: [
                    // 背景滑动条
                    _buildSlidingBackground(itemWidth, position),
                    // 按钮本体
                    _buildButtonContent(position),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 构建滑动背景
  Widget _buildSlidingBackground(double itemWidth, double position) {
    return Positioned.fill(
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(4),
        child: Transform.translate(
          offset: Offset(position * itemWidth, 0),
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
      ),
    );
  }

  /// 构建按钮内容
  Widget _buildButtonContent(double position) {
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Center(
                child: Builder(
                  builder: (context) {
                    // 计算当前索引与滑块位置的距离
                    final distance = (position - index).abs();
                    // 根据距离计算透明度和颜色
                    final opacity = (1 - (distance * 0.3)).clamp(0.0, 1.0);
                    // 选中项落在蓝色滑块上，用白字
                    final textColor = Color.lerp(
                      AppColors.fg(context).withValues(alpha: 0.6),
                      isSelected ? Colors.white : AppColors.fg(context),
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
  }
}
