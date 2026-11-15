import 'dart:ui';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/common/app_localizations.dart';

class TransferDialog extends ConsumerStatefulWidget {
  const TransferDialog({super.key});

  @override
  ConsumerState<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<TransferDialog> {
  final TextEditingController _amountController = TextEditingController();
  bool _isTransferring = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.read(inviteProvider);
    final double maxAmount = inviteState.availableCommission; // 已经是元，不需要再除以100
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth > 600 ? 500 : double.infinity,
              maxHeight: screenHeight * 0.85,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
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
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          appLocalizations.transferToWallet,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                              color: Colors.white.withValues(alpha: 0.6),
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
                              : _isTransferring
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
                                  appLocalizations.transferSuccess,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                  key: const ValueKey('success-text'),
                                )
                              : _isTransferring
                                  ? Text(
                                      appLocalizations.transferring,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      key: const ValueKey('loading-text'),
                                    )
                                  : Text(
                                      appLocalizations.maxTransferable(
                                          inviteState.availableCommission
                                              .toStringAsFixed(2)),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      key: const ValueKey('balance-text'),
                                    ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isTransferring && !_isSuccess) ...[
                          TextField(
                            controller: _amountController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: appLocalizations.transferAmount,
                              labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7)),
                              hintText: appLocalizations.enterTransferAmount,
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.blue.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              suffixText: '¥',
                              suffixStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7)),
                              helperText: appLocalizations.maxTransferable(
                                  maxAmount.toStringAsFixed(2)),
                              helperStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            appLocalizations.transferNote,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.6),
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
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!_isTransferring && !_isSuccess) ...[
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
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                appLocalizations.cancel,
                                style: const TextStyle(
                                  color: Colors.white,
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
                            onTap: () => _performTransfer(maxAmount),
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
                                appLocalizations.confirmTransfer,
                                style: const TextStyle(
                                  color: Colors.white,
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

  Future<void> _performTransfer(double maxAmount) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      if (mounted) {
        XBoardNotification.showError(appLocalizations.enterTransferAmountError);
      }
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (mounted) {
        XBoardNotification.showError(appLocalizations.invalidTransferAmount);
      }
      return;
    }

    if (amount > maxAmount) {
      if (mounted) {
        XBoardNotification.showError(appLocalizations
            .transferAmountExceeded(maxAmount.toStringAsFixed(2)));
      }
      return;
    }

    setState(() {
      _isTransferring = true;
    });

    try {
      final result =
          await ref.read(inviteProvider.notifier).transferCommission(amount);

      if (mounted) {
        setState(() {
          _isTransferring = false;
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
                XBoardNotification.showSuccess(appLocalizations
                    .transferSuccessMsg(amount.toStringAsFixed(2)));
              }
            });
          }
        } else {
          XBoardNotification.showError(appLocalizations.transferFailed("划转失败"));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _isSuccess = false;
        });
        XBoardNotification.showError(
            appLocalizations.transferFailed(e.toString()));
      }
    }
  }
}
