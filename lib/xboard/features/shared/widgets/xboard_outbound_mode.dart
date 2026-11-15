import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/shared/widgets/glass_container.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'tun_introduction_dialog.dart';
import 'package:fl_clash/l10n/l10n.dart';

// 初始化文件级日志器
final _logger = FileLogger('xboard_outbound_mode.dart');

class XBoardOutboundMode extends StatelessWidget {
  const XBoardOutboundMode({super.key});

  Future<void> _refreshSubscription(WidgetRef ref) async {
    try {
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
    } catch (e, st) {
      _logger.error('[XBoardOutboundMode] 刷新订阅失败: $e', e, st);
    }
  }

  void _handleModeChange(WidgetRef ref, Mode modeOption) {
    _logger.debug('[XBoardOutboundMode] 切换模式到: $modeOption');
    globalState.appController.changeMode(modeOption);
    // controller.changeMode 已经处理了全局模式的自动节点选择
  }

  Future<void> _handleTunToggle(
      BuildContext context, WidgetRef ref, bool selected) async {
    if (selected) {
      final storageService = ref.read(storageServiceProvider);
      final hasShownResult = await storageService.hasTunFirstUseShown();
      final hasShown = hasShownResult.dataOrNull ?? false;
      if (!hasShown) {
        if (context.mounted) {
          final shouldEnable = await TunIntroductionDialog.show(context);
          if (shouldEnable == true) {
            await storageService.markTunFirstUseShown();
            ref.read(patchClashConfigProvider.notifier).updateState(
                  (state) => state.copyWith.tun(enable: true),
                );
          }
        }
      } else {
        ref.read(patchClashConfigProvider.notifier).updateState(
              (state) => state.copyWith.tun(enable: true),
            );
      }
    } else {
      ref.read(patchClashConfigProvider.notifier).updateState(
            (state) => state.copyWith.tun(enable: false),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tunSelectedColor = isDark
        ? Colors.green.shade800.withValues(alpha: 0.4)
        : Colors.green.withValues(alpha: 0.2);
    final tunCheckmarkColor =
        isDark ? Colors.green.shade300 : Colors.green.shade700;
    final tunBorderColor =
        isDark ? Colors.green.shade600 : Colors.green.shade300;

    return Consumer(
      builder: (context, ref, child) {
        final mode =
            ref.watch(patchClashConfigProvider.select((state) => state.mode));
        final tunEnabled = ref.watch(
            patchClashConfigProvider.select((state) => state.tun.enable));
        return GlassContainer(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(14.0),
          opacity: 0.05,
          blur: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).xboardProxyMode,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          alignment: mode == Mode.rule
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: Container(
                            width: 80,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => _handleModeChange(ref, Mode.rule),
                                child: Center(
                                  child: Text(
                                    Intl.message(Mode.rule.name),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: mode == Mode.rule
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () =>
                                    _handleModeChange(ref, Mode.global),
                                child: Center(
                                  child: Text(
                                    Intl.message(Mode.global.name),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: mode == Mode.global
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text("TUN"),
                    selected: tunEnabled,
                    onSelected: (selected) {
                      _handleTunToggle(context, ref, selected);
                    },
                    selectedColor: tunSelectedColor,
                    checkmarkColor: tunCheckmarkColor,
                    side: tunEnabled
                        ? BorderSide(color: tunBorderColor, width: 1)
                        : null,
                    labelStyle: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _getModeDescription(mode, tunEnabled, context),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getModeDescription(Mode mode, bool tunEnabled, BuildContext context) {
    final tunStatus =
        tunEnabled ? ' | ${AppLocalizations.of(context).xboardTunEnabled}' : '';
    switch (mode) {
      case Mode.rule:
        return '${AppLocalizations.of(context).xboardProxyModeRuleDescription}$tunStatus';
      case Mode.global:
        return '${AppLocalizations.of(context).xboardProxyModeGlobalDescription}$tunStatus';
      case Mode.direct:
        return '${AppLocalizations.of(context).xboardProxyModeDirectDescription}$tunStatus';
    }
  }
}
