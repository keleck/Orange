import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/theme_dialog.dart';
import 'package:fl_clash/common/app_localizations.dart';

class UserMenuWidget extends ConsumerWidget {
  const UserMenuWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return PopupMenuButton<String>(
      icon: Icon(Icons.person, color: Colors.white.withValues(alpha: 0.8)),
      tooltip: appLocalizations.userCenter,
      onSelected: (value) {
        if (value == 'theme') {
          _showThemeDialog(context);
        }
      },
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.transparent,
      elevation: 0,
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'theme',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.brightness_6,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      appLocalizations.switchTheme,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ThemeDialog(),
    );
  }
}
