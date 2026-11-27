import 'dart:io';
import 'dart:math';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/measure.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记住上一次生效的明暗，供 macOS 原生启动画面读取。
/// 启动画面在 Flutter 起来之前就要绘制，读不到 Dart 侧的主题设置，
/// 只能靠上一次运行时写进 NSUserDefaults 的值。
class SplashThemeCache {
  static bool? _last;

  static void sync(BuildContext context) {
    if (!Platform.isMacOS) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_last == isDark) return;
    _last = isDark;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('splash_dark', isDark),
    );
  }
}

class ThemeManager extends ConsumerWidget {
  final Widget child;

  const ThemeManager({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, ref) {
    SplashThemeCache.sync(context);
    final textScale = ref.read(
      themeSettingProvider.select((state) => state.textScale),
    );
    final double textScaleFactor = max(
      min(
        textScale.enable ? textScale.scale : defaultTextScaleFactor,
        maxTextScale,
      ),
      minTextScale,
    );

    globalState.measure = Measure.of(context, textScaleFactor);
    globalState.theme = CommonTheme.of(context, textScaleFactor);
    final padding = MediaQuery.of(context).padding;
    final height = MediaQuery.of(context).size.height;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          textScaleFactor,
        ),
        padding: padding.copyWith(
          top: padding.top > height * 0.3 ? 20.0 : padding.top + 20.0,
        ),
      ),
      child: LayoutBuilder(
        builder: (_, container) {
          globalState.appController.updateViewSize(
            Size(
              container.maxWidth,
              container.maxHeight,
            ),
          );
          return child;
        },
      ),
    );
  }
}
