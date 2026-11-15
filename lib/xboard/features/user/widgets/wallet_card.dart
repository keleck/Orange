import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:flutter/services.dart';
import 'package:fl_clash/widgets/app_colors.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/payment/widgets/payment_method_selector_dialog.dart';
import 'package:fl_clash/xboard/features/payment/widgets/payment_waiting_overlay.dart';
import 'package:fl_clash/xboard/features/payment/models/payment_step.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/features/payment/pages/payment_gateway_page.dart';
import 'package:fl_clash/xboard/features/payment/pages/qrcode_payment_page.dart';
import 'package:fl_clash/xboard/domain/models/payment_method.dart';
import 'package:fl_clash/l10n/l10n.dart';

class WalletCard extends ConsumerStatefulWidget {
  const WalletCard({super.key});

  @override
  ConsumerState<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends ConsumerState<WalletCard> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(xboardPaymentProvider.notifier).loadPaymentMethods();
    });
  }

  Future<void> _handleTopUp(double amount) async {
    try {
      if (mounted) {
        PaymentWaitingManager.show(
          context,
          onClose: () => Navigator.of(context).pop(),
          onPaymentSuccess: _handlePaymentSuccess,
        );
        PaymentWaitingManager.updateStep(PaymentStep.createOrder);
      }

      debugPrint('WalletCard: Creating Top-Up Order...');
      final tradeNo = await XBoardSDK.instance.order.createTopUpOrder(amount);
      debugPrint('WalletCard: Order Created. TradeNo: $tradeNo');
      PaymentWaitingManager.updateTradeNo(tradeNo);

      debugPrint('WalletCard: Loading Payment Methods...');
      await ref.read(xboardPaymentProvider.notifier).loadPaymentMethods();
      final paymentMethods = ref.read(xboardAvailablePaymentMethodsProvider);
      debugPrint(
          'WalletCard: Payment Methods Loaded. Count: ${paymentMethods.length}');

      if (paymentMethods.isEmpty) {
        throw Exception('暂无可用的支付方式');
      }

      DomainPaymentMethod? selectedMethod;
      if (paymentMethods.length == 1) {
        selectedMethod = paymentMethods.first;
        debugPrint(
            'WalletCard: Auto-selected single payment method: ${selectedMethod.name}');
      } else {
        debugPrint(
            'WalletCard: Hiding Waiting Overlay and Showing Selector Dialog...');
        PaymentWaitingManager.hide();
        if (!mounted) {
          debugPrint('WalletCard: Not mounted after hiding overlay.');
          return;
        }
        selectedMethod = await PaymentMethodSelectorDialog.show(
          context,
          paymentMethods: paymentMethods,
        );
        debugPrint(
            'WalletCard: Dialog returned. Selected: ${selectedMethod?.name}');
        if (selectedMethod == null) return;
        if (mounted) {
          PaymentWaitingManager.show(
            context,
            onClose: () => Navigator.of(context).pop(),
            onPaymentSuccess: _handlePaymentSuccess,
            tradeNo: tradeNo,
          );
        }
      }

      debugPrint('WalletCard: Submitting Payment...');
      final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
      final paymentResult = await paymentNotifier.submitPayment(
        tradeNo: tradeNo,
        method: selectedMethod.id.toString(),
      );

      if (paymentResult == null) {
        throw Exception('支付请求失败');
      }

      paymentResult.when(
        success: (transactionId, message, extra) {
          debugPrint('[WalletCard] 支付成功 - TradeNo: $tradeNo');
          _handlePaymentSuccess();
        },
        redirect: (url, method, headers) {
          debugPrint('[WalletCard] 支付重定向 - TradeNo: $tradeNo, URL: $url');
          if (mounted) {
            PaymentWaitingManager.hide();
            // 检查是否是二维码支付
            if (_isQRCodePayment(url)) {
              debugPrint('[WalletCard] 检测到二维码支付 - TradeNo: $tradeNo');
              _showQRCodePayment(url, tradeNo);
            } else {
              debugPrint('[WalletCard] 使用网页支付 - TradeNo: $tradeNo');
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (context) => PaymentGatewayPage(
                    paymentUrl: url,
                    tradeNo: tradeNo,
                  ),
                ),
              )
                  .then((_) {
                debugPrint('[WalletCard] 支付页面返回 - TradeNo: $tradeNo');
                ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
              });
            }
          }
        },
        failed: (message, errorCode, extra) {
          debugPrint('[WalletCard] 支付失败 - TradeNo: $tradeNo, Error: $message');
          throw Exception(message);
        },
        canceled: (message) {
          debugPrint('[WalletCard] 支付取消 - TradeNo: $tradeNo');
        },
      );
    } catch (e) {
      if (mounted) {
        PaymentWaitingManager.hide();
        XBoardNotification.showError('充值失败: $e');
      }
    }
  }

  void _handlePaymentSuccess() {
    ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
    if (mounted) {
      XBoardNotification.showSuccess('充值成功');
      PaymentWaitingManager.hide();
    }
  }

  Future<void> _showCustomAmountDialog() async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.24),
                            ),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '自定义金额',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '请输入您想要充值的金额',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.06),
                                Colors.white.withValues(alpha: 0.03),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)
                                  .xboardTopupAmount,
                              labelStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                              prefixIcon: Padding(
                                padding:
                                    const EdgeInsets.only(left: 12, right: 4),
                                child: Text(
                                  '¥',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            autofocus: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.08),
                                        Colors.white.withValues(alpha: 0.04),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '取消',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final amount = double.tryParse(controller.text);
                              if (amount != null && amount > 0) {
                                Navigator.pop(context);
                                _handleTopUp(amount);
                              } else {
                                XBoardNotification.showError('请输入有效的金额');
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.75),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.10),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    '确认充值',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassmorphicDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userInfoProvider);
    final balance = user?.balanceInYuan ?? 0.0;
    final autoRenew = user?.autoRenewal ?? false;
    final theme = Theme.of(context);

    return Column(
      children: [
        // 余额卡片：与页面同一套深色渐变，仅用主题色轻提亮
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.10),
                  AppColors.gradientColor1,
                ),
                Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.03),
                  AppColors.gradientColor2,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.2),
                        theme.colorScheme.tertiary.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '账户余额',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: balance),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      '¥${value.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.6),
                        theme.colorScheme.surface.withValues(alpha: 0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '可用于购买套餐和续费',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 自动续费开关 - 液态玻璃卡片
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: _glassmorphicDecoration(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: autoRenew
                            ? Colors.green.withOpacity(0.1)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.autorenew_rounded,
                        size: 22,
                        color: autoRenew
                            ? Colors.green
                            : theme.iconTheme.color?.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '自动续费',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '套餐到期时自动使用余额续费',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _isLoading
                        ? const SizedBox(
                            width: 40,
                            height: 24,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : Switch.adaptive(
                            value: autoRenew,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (value) async {
                              setState(() {
                                _isLoading = true;
                              });
                              try {
                                await XBoardSDK.instance.user.updateUserInfo({
                                  'auto_renewal': value ? 1 : 0,
                                });
                                await ref
                                    .read(xboardUserAuthProvider.notifier)
                                    .refreshUserInfo();
                                if (mounted) {
                                  XBoardNotification.showSuccess(
                                      value ? '已开启自动续费' : '已关闭自动续费');
                                }
                              } catch (e) {
                                if (mounted) {
                                  XBoardNotification.showError('操作失败: $e');
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }
                            },
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 充值区域 - 液态玻璃卡片
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: _glassmorphicDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add_card_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '账户充值',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '充值后的余额将立即到账，可用于购买套餐服务',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.5,
                      padding: EdgeInsets.zero, // 移除 GridView 的默认 padding
                      children: [10, 30, 50, 100, 200, 500].map((amount) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Material(
                              color: Colors.transparent,
                              elevation: 0,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: () => _handleTopUp(amount.toDouble()),
                                borderRadius: BorderRadius.circular(14),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color:
                                        Colors.white.withValues(alpha: 0.045),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '¥$amount',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12), // 添加一个小的固定间距
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: ElevatedButton.icon(
                            onPressed: _showCustomAmountDialog,
                            icon: Icon(
                              Icons.edit_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              '自定义金额',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
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

  /// 判断是否是二维码支付
  bool _isQRCodePayment(String url) {
    final lowerUrl = url.toLowerCase();

    return lowerUrl.contains('qr.alipay.com') || // 支付宝二维码链接
        lowerUrl.contains('mclient.alipay.com') || // 支付宝移动端（会唤起客户端）
        lowerUrl.contains('pay.weixin.qq.com') || // 微信支付链接
        lowerUrl.contains('qr') || // 通用二维码标识
        lowerUrl.contains('qrcode') || // 二维码代码
        lowerUrl.contains('二维码') || // 中文二维码
        lowerUrl.contains('alipay_qr') || // 支付宝二维码
        lowerUrl.contains('wechat_qr') || // 微信二维码
        lowerUrl.startsWith('data:image'); // Base64 图像数据
  }

  /// 显示二维码支付页面
  Future<void> _showQRCodePayment(String qrData, String tradeNo) async {
    try {
      if (!mounted) return;

      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => QRCodePaymentPage(
            qrCodeData: qrData,
            tradeNo: tradeNo,
          ),
        ),
      )
          .then((_) {
        ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
      });
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError('显示二维码失败: $e');
      }
    }
  }
}
