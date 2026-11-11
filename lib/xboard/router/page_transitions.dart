import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 带「淡入 + 轻微右滑」过渡的页面。
///
/// go_router 里大量路由用的是 [NoTransitionPage]（页面直接硬切，没有任何动效），
/// 这里提供一个统一的自定义 Page，让二级页面的进入/返回都有过渡。
class SlideFadePage<T> extends Page<T> {
  final Widget child;
  final Duration duration;
  final Duration reverseDuration;

  const SlideFadePage({
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.reverseDuration = const Duration(milliseconds: 200),
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

/// 底部 Tab 之间切换时使用的淡入淡出（不改变 IndexedStack 的状态保持）
class TabFadeSwitcher extends StatelessWidget {
  final Widget child;
  final int index;

  const TabFadeSwitcher({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.99, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      // key 只跟 index 绑定，保证同一 tab 内部重建不触发过渡
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: child,
      ),
    );
  }
}
