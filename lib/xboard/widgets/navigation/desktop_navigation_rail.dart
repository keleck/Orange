import 'dart:ui';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:fl_clash/xboard/features/invite/widgets/user_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 桌面端侧边导航栏
class DesktopNavigationRail extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const DesktopNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 88,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 12,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 24),
              
              // 导航项
              Expanded(
                child: _buildNavigationItems(context, colorScheme),
              ),
              
              // 底部功能区
              _buildBottomActions(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  /// 分隔线
  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      width: 40,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            colorScheme.outline.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  /// 导航项
  Widget _buildNavigationItems(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final appLocalizations = AppLocalizations.of(context);
    
    return NavigationRail(
      backgroundColor: Colors.transparent,
      selectedIndex: selectedIndex,
      extended: false,
      labelType: NavigationRailLabelType.all,
      leading: null,
      useIndicator: true,
      indicatorColor: colorScheme.primaryContainer,
      selectedIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 26,
      ),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colorScheme.primary,
      ),
      unselectedIconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 11,
        color: colorScheme.onSurfaceVariant,
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: Text(appLocalizations.xboardHome),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.shopping_bag_outlined),
          selectedIcon: const Icon(Icons.shopping_bag),
          label: Text(appLocalizations.xboardPlans),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: const Text('我的'),
        ),
      ],
      onDestinationSelected: onDestinationSelected,
    );
  }

  /// 底部功能区
  Widget _buildBottomActions(ColorScheme colorScheme) {
    return const SizedBox(height: 16);
  }
}

