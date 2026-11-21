import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/widgets/app_colors.dart';

class WithdrawDialog extends ConsumerStatefulWidget {
  const WithdrawDialog({super.key});

  @override
  ConsumerState<WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends ConsumerState<WithdrawDialog> {
  final TextEditingController _accountController = TextEditingController();
  bool _isWithdrawing = false;
  bool _isSuccess = false;

  // 提现方式列表
  // TODO: 未来可以通过 SystemConfig API 从后端获取: config.withdrawMethods
  // 接口: /api/v1/user/comm/config -> SystemConfig.withdrawMethods
  final List<String> _withdrawMethods = ['支付宝', '微信', '银行卡', 'PayPal', 'USDT'];
  String? _selectedMethod;

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.read(inviteProvider);
    final double availableAmount =
        inviteState.availableCommission; // 已经是元，不需要再除以100
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppColors.isDark(context) ? 12 : 0,
            sigmaY: AppColors.isDark(context) ? 12 : 0,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth > 600 ? 500 : double.infinity,
              maxHeight: screenHeight * 0.85,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.isDark(context)
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.withValues(alpha: 0.15),
                        AppColors.surface(context, 0.08),
                      ],
                    )
                  : null,
              color: AppColors.isDark(context)
                  ? null
                  : AppColors.lightSurfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.fg(context).withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context, 0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.surface(context, 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          appLocalizations.withdrawCommission,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.fg(context),
                                  ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.close_rounded,
                              color:
                                  AppColors.fg(context).withValues(alpha: 0.6),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isSuccess
                              ? const Icon(
                                  Icons.check_circle,
                                  size: 48,
                                  color: Colors.green,
                                  key: ValueKey('success'),
                                )
                              : _isWithdrawing
                                  ? const SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: CircularProgressIndicator(
                                        key: ValueKey('loading'),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.account_balance_wallet,
                                      size: 48,
                                      color: Colors.blue,
                                      key: ValueKey('wallet'),
                                    ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isSuccess
                              ? Text(
                                  '提现申请已提交',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                  key: const ValueKey('success-text'),
                                )
                              : _isWithdrawing
                                  ? Text(
                                      '提交中...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fg(context),
                                      ),
                                      key: const ValueKey('loading-text'),
                                    )
                                  : Text(
                                      '可提现金额：¥${availableAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.fg(context),
                                      ),
                                      key: const ValueKey('balance-text'),
                                    ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isWithdrawing && !_isSuccess) ...[
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showMethodSelector(),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.fg(context)
                                        .withValues(alpha: 0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.payment,
                                            color: AppColors.fg(context)
                                                .withValues(alpha: 0.7),
                                            size: 20),
                                        const SizedBox(width: 12),
                                        Text(
                                          _selectedMethod ?? '请选择提现方式',
                                          style: TextStyle(
                                            color: _selectedMethod != null
                                                ? AppColors.fg(context)
                                                : AppColors.fg(context)
                                                    .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.fg(context)
                                          .withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _accountController,
                            style: TextStyle(color: AppColors.fg(context)),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)
                                  .xboardWithdrawAccount,
                              labelStyle: TextStyle(
                                  color: AppColors.fg(context)
                                      .withValues(alpha: 0.7)),
                              hintText: AppLocalizations.of(context)
                                  .xboardEnterAccount,
                              hintStyle: TextStyle(
                                  color: AppColors.fg(context)
                                      .withValues(alpha: 0.5)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppColors.fg(context)
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppColors.fg(context)
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.blue.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(Icons.account_box,
                                  color: AppColors.fg(context)
                                      .withValues(alpha: 0.7)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '提现申请将通过工单系统提交，请等待管理员审核',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  AppColors.fg(context).withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.surface(context, 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!_isWithdrawing && !_isSuccess) ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.fg(context)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.fg(context)
                                      .withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                appLocalizations.cancel,
                                style: TextStyle(
                                  color: AppColors.fg(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _performWithdraw,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400.withValues(alpha: 0.6),
                                    Colors.blue.shade600.withValues(alpha: 0.4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '提交申请',
                                style: TextStyle(
                                  color: AppColors.fg(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performWithdraw() async {
    if (_selectedMethod == null || _selectedMethod!.isEmpty) {
      if (mounted) {
        XBoardNotification.showError('请选择提现方式');
      }
      return;
    }

    final account = _accountController.text.trim();
    if (account.isEmpty) {
      if (mounted) {
        XBoardNotification.showError('请输入提现账号');
      }
      return;
    }

    setState(() {
      _isWithdrawing = true;
    });

    try {
      final result = await ref.read(inviteProvider.notifier).withdrawCommission(
            withdrawMethod: _selectedMethod!,
            withdrawAccount: account,
          );

      if (mounted) {
        setState(() {
          _isWithdrawing = false;
          _isSuccess = result;
        });

        if (result) {
          // 成功后显示动画，然后自动关闭
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            // 关闭后显示提示
            Future.microtask(() {
              if (mounted) {
                XBoardNotification.showSuccess('提现申请已提交，请等待审核');
              }
            });
          }
        } else {
          XBoardNotification.showError('提交失败');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWithdrawing = false;
          _isSuccess = false;
        });
        XBoardNotification.showError('提交失败：$e');
      }
    }
  }

  void _showMethodSelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.isDark(context)
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.withValues(alpha: 0.15),
                          AppColors.surface(context, 0.08),
                        ],
                      )
                    : null,
                color: AppColors.isDark(context)
                    ? null
                    : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.fg(context).withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context, 0.08),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.surface(context, 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '选择提现方式',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.fg(context),
                                ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.close_rounded,
                                color: AppColors.fg(context)
                                    .withValues(alpha: 0.6),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _withdrawMethods.map((method) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedMethod = method;
                                });
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: _selectedMethod == method
                                      ? Colors.blue.withValues(alpha: 0.3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedMethod == method
                                        ? Colors.blue.withValues(alpha: 0.5)
                                        : AppColors.fg(context)
                                            .withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedMethod == method
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: AppColors.fg(context).withValues(
                                        alpha: _selectedMethod == method
                                            ? 1.0
                                            : 0.6,
                                      ),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      method,
                                      style: TextStyle(
                                        color: AppColors.fg(context).withValues(
                                          alpha: _selectedMethod == method
                                              ? 1.0
                                              : 0.7,
                                        ),
                                        fontWeight: _selectedMethod == method
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
