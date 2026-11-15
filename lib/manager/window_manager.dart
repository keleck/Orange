import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_ext/window_ext.dart';
import 'package:window_manager/window_manager.dart';
import 'package:fl_clash/l10n/l10n.dart';

class WindowManager extends ConsumerStatefulWidget {
  final Widget child;

  const WindowManager({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<WindowManager> createState() => _WindowContainerState();
}

class _WindowContainerState extends ConsumerState<WindowManager>
    with WindowListener, WindowExtListener {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      appSettingProvider.select((state) => state.autoLaunch),
      (prev, next) {
        if (prev != next) {
          debouncer.call(
            FunctionTag.autoLaunch,
            () {
              autoLaunch?.updateStatus(next);
            },
          );
        }
      },
    );
    windowExtManager.addListener(this);
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    await globalState.appController.handleBackOrExit();
    super.onWindowClose();
  }

  @override
  void onWindowFocus() {
    super.onWindowFocus();
    commonPrint.log("focus");
    render?.resume();
  }

  @override
  Future<void> onShouldTerminate() async {
    await globalState.appController.handleExit();
    super.onShouldTerminate();
  }

  @override
  Future<void> onWindowMoved() async {
    super.onWindowMoved();
    final offset = await windowManager.getPosition();
    ref.read(windowSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            top: offset.dy,
            left: offset.dx,
          ),
        );
  }

  @override
  Future<void> onWindowResized() async {
    super.onWindowResized();
    final size = await windowManager.getSize();
    ref.read(windowSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            width: size.width,
            height: size.height,
          ),
        );
  }

  @override
  void onWindowMinimize() async {
    globalState.appController.savePreferencesDebounce();
    commonPrint.log("minimize");
    render?.pause();
    super.onWindowMinimize();
  }

  @override
  void onWindowRestore() {
    commonPrint.log("restore");
    render?.resume();
    super.onWindowRestore();
  }

  @override
  Future<void> dispose() async {
    windowManager.removeListener(this);
    windowExtManager.removeListener(this);
    super.dispose();
  }
}

class WindowHeaderContainer extends StatelessWidget {
  final Widget child;

  const WindowHeaderContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 桌面平台在左上角显示窗口控制按钮和拖拽区域
    if (system.isDesktop) {
      return Stack(
        children: [
          child,
          // 顶部拖拽区域
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onPanStart: (_) {
                windowManager.startDragging();
              },
              child: Container(
                height: 30,
                color: Colors.transparent,
              ),
            ),
          ),
          // 窗口控制按钮
          const Positioned(
            top: 0,
            left: 0,
            child: WindowControlButtons(),
          ),
        ],
      );
    }
    return child;
  }
}

class WindowControlButtons extends StatelessWidget {
  const WindowControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    // 仅在 Windows 平台显示窗口控制按钮
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WindowButton(
            icon: Icons.remove,
            tooltip: AppLocalizations.of(context).xboardMinimize,
            onTap: () async {
              await windowManager.minimize();
            },
          ),
          _WindowButton(
            icon: Icons.close,
            tooltip: AppLocalizations.of(context).close,
            onTap: () async {
              await globalState.appController.handleBackOrExit();
            },
            isClose: true,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isClose
                    ? Colors.red.withOpacity(0.6)
                    : Colors.white.withOpacity(0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 14,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ),
      ),
    );
  }
}

class WindowHeader extends StatefulWidget {
  const WindowHeader({super.key});

  @override
  State<WindowHeader> createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  final isMaximizedNotifier = ValueNotifier<bool>(false);
  final isPinNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _initNotifier();
  }

  _initNotifier() async {
    isMaximizedNotifier.value = await windowManager.isMaximized();
    isPinNotifier.value = await windowManager.isAlwaysOnTop();
  }

  @override
  void dispose() {
    isMaximizedNotifier.dispose();
    isPinNotifier.dispose();
    super.dispose();
  }

  _updateMaximized() async {
    final isMaximized = await windowManager.isMaximized();
    switch (isMaximized) {
      case true:
        await windowManager.unmaximize();
        break;
      case false:
        await windowManager.maximize();
        break;
    }
    isMaximizedNotifier.value = await windowManager.isMaximized();
  }

  _updatePin() async {
    final isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    await windowManager.setAlwaysOnTop(!isAlwaysOnTop);
    isPinNotifier.value = await windowManager.isAlwaysOnTop();
  }

  _buildActions() {
    // 仅在 Windows 平台显示窗口控制按钮
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        IconButton(
          onPressed: () async {
            _updatePin();
          },
          icon: ValueListenableBuilder(
            valueListenable: isPinNotifier,
            builder: (_, value, ___) {
              return value
                  ? const Icon(
                      Icons.push_pin,
                    )
                  : const Icon(
                      Icons.push_pin_outlined,
                    );
            },
          ),
        ),
        IconButton(
          onPressed: () {
            windowManager.minimize();
          },
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          onPressed: () async {
            _updateMaximized();
          },
          icon: ValueListenableBuilder(
            valueListenable: isMaximizedNotifier,
            builder: (_, value, ___) {
              return value
                  ? const Icon(
                      Icons.filter_none,
                      size: 20,
                    )
                  : const Icon(
                      Icons.crop_square,
                    );
            },
          ),
        ),
        IconButton(
          onPressed: () {
            globalState.appController.handleBackOrExit();
          },
          icon: const Icon(Icons.close),
        ),
        // const SizedBox(
        //   width: 8,
        // ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          Positioned(
            child: GestureDetector(
              onPanStart: (_) {
                windowManager.startDragging();
              },
              onDoubleTap: () {
                _updateMaximized();
              },
              child: Container(
                color: context.colorScheme.secondary.opacity15,
                alignment: Alignment.centerLeft,
                height: kHeaderHeight,
              ),
            ),
          ),
          if (Platform.isMacOS)
            const Text(
              appName,
            )
          else ...[
            const Positioned(
              left: 0,
              child: AppIcon(),
            ),
            Positioned(
              right: 0,
              child: _buildActions(),
            ),
          ]
        ],
      ),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircleAvatar(
              foregroundImage: AssetImage("assets/images/icon.png"),
              backgroundColor: Colors.transparent,
            ),
          ),
          SizedBox(
            width: 8,
          ),
          Text(
            appName,
          ),
        ],
      ),
    );
  }
}
