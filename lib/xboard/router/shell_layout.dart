import 'dart:io';
import 'package:fl_clash/xboard/widgets/navigation/desktop_navigation_rail.dart';
import 'package:fl_clash/xboard/widgets/navigation/mobile_navigation_bar.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 适配性的 Shell 布局
/// 桌面端：侧边栏 + 内容区
/// 移动端：底部导航栏 + 内容区
class AdaptiveShellLayout extends ConsumerWidget {
  final StatefulNavigationShell child;

  const AdaptiveShellLayout({
    super.key,
    required this.child,
  });

  void _onDestinationSelected(BuildContext context, int index, bool isDesktop) {
    if (isDesktop) {
      // 桌面端路由：首页、套餐、我的
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/plans');
          break;
        case 2:
          context.go('/user');
          break;
      }
    } else {
      // 移动端路由：首页、套餐、我的
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/plans');
          break;
        case 2:
          context.go('/user');
          break;
      }
    }
  }

  int _getCurrentIndex(BuildContext context, bool isDesktop) {
    final location = GoRouterState.of(context).uri.path;

    if (isDesktop) {
      // 桌面端导航栏索引：首页(0)、套餐(1)、我的(2)
      if (location == '/') return 0;
      if (location.startsWith('/plans')) return 1;
      if (location.startsWith('/user')) return 2;
      return 0;
    } else {
      // 移动端导航栏索引：首页(0)、套餐(1)、我的(2)
      if (location.startsWith('/plans')) return 1;
      if (location.startsWith('/user')) return 2;
      return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用 ViewMode 来判断布局，而不是平台类型
    final viewMode = ref.watch(viewModeProvider);
    final isDesktop = viewMode != ViewMode.mobile;
    final currentIndex = _getCurrentIndex(context, isDesktop);

    if (isDesktop) {
      // 桌面端：侧边栏 + 内容区（无外层 Scaffold）
      return Row(
        children: [
          DesktopNavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index, true),
          ),
          Expanded(
            child: child,
          ),
        ],
      );
    } else {
      // 移动端：Scaffold + 底部导航栏
      // Support 页面不显示底部导航栏
      final location = GoRouterState.of(context).uri.path;
      final hideBottomNav = location.startsWith('/support');

      return Scaffold(
        extendBody: true, // 让内容延伸到底部导航栏下方，实现悬浮效果
        body: child,
        bottomNavigationBar: hideBottomNav
            ? null
            : MobileNavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: (index) =>
                    _onDestinationSelected(context, index, false),
              ),
      );
    }
  }
}
