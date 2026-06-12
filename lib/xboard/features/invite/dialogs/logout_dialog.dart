import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';

class LogoutDialog extends ConsumerWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text(appLocalizations.confirmLogout),
      content: Text(appLocalizations.logoutConfirmMsg),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await _performLogout(context, ref);
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: Text(appLocalizations.logout),
        ),
      ],
    );
  }

  Future<void> _performLogout(BuildContext context, WidgetRef ref) async {
    try {
      // 检查是否有节点连接
      final isConnected = ref.read(runTimeProvider) != null;
      
      // 如果有连接，先断开节点
      if (isConnected) {
        XBoardNotification.showInfo('正在断开节点连接...');
        globalState.appController.updateStatus(false);
        
        // 等待连接断开（runTimeProvider 变为 null）
        int waitCount = 0;
        while (ref.read(runTimeProvider) != null && waitCount < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }
      }
      
      // 执行退出登录
      await ref.read(xboardUserProvider.notifier).logout();
      if (context.mounted) {
        XBoardNotification.showSuccess(appLocalizations.loggedOutSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        XBoardNotification.showError(appLocalizations.logoutFailed(e.toString()));
      }
    }
  }
}