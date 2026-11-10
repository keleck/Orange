import 'dart:async';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_checker.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 内核（Clash Meta）运行状态
enum CoreHealthStatus {
  /// 首次检测中
  checking,

  /// 内核存活
  running,

  /// 内核未响应 / 未启动
  stopped,

  /// 正在重启
  restarting,
}

/// 内核状态指示灯
///
/// 放在首页「规则 / 全局」切换按钮旁边，用于直观展示内核是否存活。
/// 单击即可重启内核，并自动重新拉取订阅下发配置
/// （核心重启后配置为空，不重新下发则节点不可用）。
class CoreStatusButton extends ConsumerStatefulWidget {
  const CoreStatusButton({
    super.key,
    this.compact = false,
  });

  /// 紧凑模式：只显示状态圆点，不显示文字（窄屏使用，避免挤压布局）
  final bool compact;

  @override
  ConsumerState<CoreStatusButton> createState() => _CoreStatusButtonState();
}

class _CoreStatusButtonState extends ConsumerState<CoreStatusButton> {
  /// 心跳间隔
  static const _probeInterval = Duration(seconds: 4);

  /// 单次探测超时（核心失联时不能卡住界面）
  static const _probeTimeout = Duration(seconds: 3);

  static const _runningColor = Color(0xFF22C55E);
  static const _stoppedColor = Color(0xFF9CA3AF);
  static const _restartingColor = Color(0xFFF59E0B);

  CoreHealthStatus _status = CoreHealthStatus.checking;
  Timer? _timer;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startHeartbeat();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startHeartbeat() {
    _timer?.cancel();
    _probe();
    _timer = Timer.periodic(_probeInterval, (_) => _probe());
  }

  /// 探测内核是否存活
  ///
  /// 桌面端先判断与内核进程的 socket 是否已建立连接，避免在核心未启动时
  /// 触发长达 30 秒的等待；随后通过读取内存占用做一次轻量探活。
  Future<bool> _isCoreAlive() async {
    try {
      if (system.isDesktop) {
        final service = clashService;
        if (service == null || !service.socketCompleter.isCompleted) {
          return false;
        }
      }
      final memory = await clashCore.getMemory().timeout(_probeTimeout);
      return memory > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _probe() async {
    if (_probing || _status == CoreHealthStatus.restarting) return;
    _probing = true;
    final alive = await _isCoreAlive();
    _probing = false;
    if (!mounted || _status == CoreHealthStatus.restarting) return;
    final next = alive ? CoreHealthStatus.running : CoreHealthStatus.stopped;
    if (next != _status) {
      setState(() => _status = next);
    }
  }

  /// 重新拉取订阅并把配置下发给内核
  ///
  /// 配置文件在首次应用后即从内存缓存与临时文件中清除，因此内核重启后
  /// 仅调用 applyProfile 拿不到配置，必须重新导入订阅，否则节点列表为空。
  Future<bool> _refreshSubscription() async {
    final subscribeUrl = ref.read(subscriptionInfoProvider)?.subscribeUrl ?? '';
    if (subscribeUrl.isNotEmpty) {
      commonPrint.log('[内核重启] 重新导入订阅配置');
      return await ref.read(profileImportProvider.notifier).importSubscription(
            subscribeUrl,
            forceRefresh: true,
          );
    }
    // 没有订阅链接时退回完整刷新流程
    commonPrint.log('[内核重启] 无订阅链接，执行完整刷新');
    if (!mounted) return false;
    await subscriptionStatusChecker.forceRefreshSubscriptionInfo(context, ref);
    return ref.read(groupsProvider).isNotEmpty;
  }

  Future<void> _restartCore() async {
    if (_status == CoreHealthStatus.restarting) return;
    setState(() => _status = CoreHealthStatus.restarting);

    final wasRunning = ref.read(runTimeProvider) != null;
    try {
      // 1. 先断开，避免内核重启后带着空配置启动
      if (wasRunning) {
        await globalState.appController.updateStatus(false);
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // 2. 重启内核
      await globalState.appController.restartCore();

      // 3. 重新拉取订阅并下发配置，否则节点列表为空
      final refreshed = await _refreshSubscription();

      // 4. 恢复连接
      if (wasRunning && refreshed) {
        await globalState.appController.updateStatus(true);
      }

      final alive = await _isCoreAlive();
      if (!mounted) return;
      setState(() {
        _status = alive ? CoreHealthStatus.running : CoreHealthStatus.stopped;
      });
      if (!alive) {
        XBoardNotification.showError('内核重启后无响应，请稍后重试');
      } else if (!refreshed) {
        // 把导入失败的原始原因带出来，否则用户只知道「失败了」，
        // 分不清是网络、订阅链接还是配置解析的问题。
        final importState = ref.read(profileImportProvider);
        final detail =
            importState.lastResult?.errorMessage ??
            importState.message ??
            '';
        XBoardNotification.showError(
          detail.isEmpty
              ? '内核已重启，但订阅刷新失败，请手动刷新订阅'
              : '订阅刷新失败: $detail',
        );
      } else {
        XBoardNotification.showSuccess('内核已重启，订阅已刷新');
      }
    } catch (e) {
      commonPrint.log('重启内核失败: $e');
      if (!mounted) return;
      setState(() => _status = CoreHealthStatus.stopped);
      XBoardNotification.showError('重启内核失败: $e');
    }
  }

  Color get _color => switch (_status) {
        CoreHealthStatus.running => _runningColor,
        CoreHealthStatus.restarting => _restartingColor,
        CoreHealthStatus.stopped => _stoppedColor,
        CoreHealthStatus.checking => _stoppedColor,
      };

  String get _label => switch (_status) {
        CoreHealthStatus.restarting => '重启中',
        _ => '内核',
      };

  String get _tooltip => switch (_status) {
        CoreHealthStatus.running => '内核运行中，点击重启内核并刷新订阅',
        CoreHealthStatus.restarting => '内核重启中…',
        CoreHealthStatus.stopped => '内核未运行，点击重启内核并刷新订阅',
        CoreHealthStatus.checking => '正在检测内核状态…',
      };

  Widget _buildIndicator(Color color) {
    if (_status == CoreHealthStatus.restarting) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final isBusy = _status == CoreHealthStatus.restarting;
    return Tooltip(
      message: _tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isBusy ? null : _restartCore,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          height: 26,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 7 : 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIndicator(color),
              if (!widget.compact) ...[
                const SizedBox(width: 5),
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.0,
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
