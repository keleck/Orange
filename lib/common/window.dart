import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  init(int version) async {
    final props = globalState.config.windowProps;
    final acquire = await singleInstanceLock.acquire();
    if (!acquire) {
      exit(0);
    }
    if (Platform.isWindows) {
      protocol.register("clash");
      protocol.register("clashmeta");
      protocol.register("flclash");
    }
    await windowManager.ensureInitialized();

    // 获取主屏幕信息
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final screenSize = primaryDisplay.size;

    // 固定手机风格的窗口尺寸 (类似 iPhone 比例)
    const double fixedWidth = 420;
    const double fixedHeight = 780;

    // 确保不超过屏幕尺寸
    final windowWidth = fixedWidth > screenSize.width * 0.9
        ? screenSize.width * 0.9
        : fixedWidth;
    final windowHeight = fixedHeight > screenSize.height * 0.9
        ? screenSize.height * 0.9
        : fixedHeight;

    WindowOptions windowOptions = WindowOptions(
      size: Size(windowWidth, windowHeight),
      minimumSize: Size(windowWidth, windowHeight), // 固定最小尺寸等于窗口尺寸
      maximumSize: Size(windowWidth, windowHeight), // 固定最大尺寸等于窗口尺寸，禁用调整大小
    );
    if (!Platform.isMacOS || version > 10) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    if (!Platform.isMacOS) {
      final left = props.left ?? 0;
      final top = props.top ?? 0;
      final right = left + props.width;
      final bottom = top + props.height;
      if (left == 0 && top == 0) {
        await windowManager.setAlignment(Alignment.center);
      } else {
        final displays = await screenRetriever.getAllDisplays();
        final isPositionValid = displays.any(
          (display) {
            final displayBounds = Rect.fromLTWH(
              display.visiblePosition!.dx,
              display.visiblePosition!.dy,
              display.size.width,
              display.size.height,
            );
            return displayBounds.contains(Offset(left, top)) ||
                displayBounds.contains(Offset(right, bottom));
          },
        );
        if (isPositionValid) {
          await windowManager.setPosition(
            Offset(
              left,
              top,
            ),
          );
        }
      }
    }
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
      await windowManager.setResizable(false); // 禁用窗口缩放
    });

    // 原生层已经盖好启动画面（macos/Runner/MainFlutterWindow.swift），
    // 这里先把窗口显示出来，让用户立刻看到品牌启动页，而不是黑框或“点了没反应”。
    // 只在 macOS 提前显示：Windows/Linux 没有这层启动画面，提前 show 会露白底。
    if (Platform.isMacOS && !globalState.config.appSetting.silentLaunch) {
      await show();
    }
  }

  show() async {
    render?.resume();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
  }

  Future<bool> get isVisible async {
    final value = await windowManager.isVisible();
    commonPrint.log("window visible check: $value");
    return value;
  }

  close() async {
    exit(0);
  }

  hide() async {
    render?.pause();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}

final window = system.isDesktop ? Window() : null;
