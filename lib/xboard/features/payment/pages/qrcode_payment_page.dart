import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'dart:async';
import 'package:fl_clash/l10n/l10n.dart';

class QRCodePaymentPage extends ConsumerStatefulWidget {
  final String qrCodeData;
  final String tradeNo;

  const QRCodePaymentPage({
    super.key,
    required this.qrCodeData,
    required this.tradeNo,
  });

  @override
  ConsumerState<QRCodePaymentPage> createState() => _QRCodePaymentPageState();
}

class _QRCodePaymentPageState extends ConsumerState<QRCodePaymentPage> {
  bool _isCheckingPayment = false;
  bool _autoPollingEnabled = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('[QRCodePayment] ===== 页面初始化 ===== TradeNo: ${widget.tradeNo}');
    _startPaymentStatusCheck();
    _startAutoPolling();
  }

  @override
  void dispose() {
    debugPrint('[QRCodePayment] ===== 页面销毁 ===== TradeNo: ${widget.tradeNo}');
    debugPrint('[QRCodePayment] 停止轮询标志: $_autoPollingEnabled -> false');
    _autoPollingEnabled = false;
    if (_pollingTimer != null) {
      debugPrint('[QRCodePayment] 取消定时器');
      _pollingTimer?.cancel();
    }
    super.dispose();
  }

  Future<void> _startPaymentStatusCheck() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _checkPaymentStatus();
    }
  }

  void _startAutoPolling() {
    if (_autoPollingEnabled) {
      debugPrint('[QRCodePayment] 轮询已启动，跳过 - TradeNo: ${widget.tradeNo}');
      return;
    }
    debugPrint('[QRCodePayment] 启动自动轮询 - TradeNo: ${widget.tradeNo}');
    setState(() {
      _autoPollingEnabled = true;
    });
    _pollPaymentStatus();
  }

  void _stopAutoPolling() {
    debugPrint('[QRCodePayment] 停止自动轮询 - TradeNo: ${widget.tradeNo}');
    setState(() {
      _autoPollingEnabled = false;
    });
    if (_pollingTimer != null) {
      debugPrint('[QRCodePayment] 取消定时器');
      _pollingTimer?.cancel();
    }
  }

  Future<void> _pollPaymentStatus() async {
    debugPrint(
        '[QRCodePayment] 轮询检查开始 - TradeNo: ${widget.tradeNo}, 启用状态: $_autoPollingEnabled, mounted: $mounted');
    if (!_autoPollingEnabled || !mounted) {
      debugPrint('[QRCodePayment] 轮询终止 (未启用或已销毁) - TradeNo: ${widget.tradeNo}');
      return;
    }
    await Future.delayed(const Duration(seconds: 5));
    if (!_autoPollingEnabled || !mounted) {
      debugPrint('[QRCodePayment] 延迟后终止轮询 - TradeNo: ${widget.tradeNo}');
      return;
    }
    await _checkPaymentStatus(silent: true);
    if (_autoPollingEnabled && mounted) {
      debugPrint('[QRCodePayment] 创建下次轮询定时器 - TradeNo: ${widget.tradeNo}');
      // 使用 Timer 替代递归调用，确保能够正确取消
      _pollingTimer = Timer(const Duration(seconds: 5), _pollPaymentStatus);
    } else {
      debugPrint('[QRCodePayment] 不再创建新的轮询 - TradeNo: ${widget.tradeNo}');
    }
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_isCheckingPayment) {
      debugPrint('[QRCodePayment] 已在检查支付状态，跳过 - TradeNo: ${widget.tradeNo}');
      return;
    }
    debugPrint(
        '[QRCodePayment] 开始检查支付状态 - TradeNo: ${widget.tradeNo}, silent: $silent');
    setState(() {
      _isCheckingPayment = true;
    });
    try {
      final orderModels = await XBoardSDK.instance.order.getOrders();
      debugPrint('[QRCodePayment] 获取到订单列表，共 ${orderModels.length} 条');
      debugPrint('[QRCodePayment] 获取到订单列表，共 ${orderModels.length} 条');
      final order = orderModels.firstWhere(
        (o) => o.tradeNo == widget.tradeNo,
        orElse: () => const OrderModel(status: -1),
      );
      debugPrint(
          '[QRCodePayment] 查找订单结果 - TradeNo: ${widget.tradeNo}, 状态: ${order.status}');

      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
        });
        if (order.status != -1) {
          if (order.status == 3) {
            // 支付成功
            _stopAutoPolling();
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                XBoardNotification.showSuccess('🎉 支付成功！');
              }
            });
            // 刷新订阅信息
            Future.microtask(() async {
              try {
                final authProvider = ref.read(xboardUserProvider.notifier);
                await authProvider.refreshSubscriptionInfoAfterPayment();
              } catch (e) {
                // 忽略刷新错误，不影响用户体验
              }
            });
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });
          } else if (order.status == 2) {
            // 支付已取消
            _stopAutoPolling();
            if (!silent) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  XBoardNotification.showInfo('支付已取消');
                }
              });
            }
          } else if (order.status == 0 || order.status == 1) {
            // 待支付或处理中
            if (!silent) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  XBoardNotification.showInfo(
                    _autoPollingEnabled ? '正在等待支付...' : '订单状态：待支付',
                  );
                }
              });
            }
          }
        } else {
          if (!silent) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                XBoardNotification.showError('未找到订单信息');
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
        });
        if (!silent) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              XBoardNotification.showError('检查支付状态失败: $e');
            }
          });
        }
      }
    }
  }

  Future<void> _copyQRCode() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.qrCodeData));
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            XBoardNotification.showSuccess('二维码数据已复制到剪贴板');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            XBoardNotification.showError('复制失败: $e');
          }
        });
      }
    }
  }

  void _completePayment() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        XBoardNotification.showSuccess('支付完成！');
      }
    });
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _cancelPayment() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: AppLocalizations.of(context).xboardQrCodePayment,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 订单信息卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '订单信息',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('订单号: '),
                            Expanded(
                              child: Text(
                                widget.tradeNo,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 二维码卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          '扫一扫完成支付',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          child: QrImageView(
                            data: widget.qrCodeData,
                            version: QrVersions.auto,
                            size: 280,
                            gapless: true,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '请使用支付宝或微信扫描二维码完成支付',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 自动检测状态卡片
                if (_autoPollingEnabled)
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '自动检测支付状态',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                Text(
                                  '系统每5秒检查一次，支付完成后会自动跳转',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _stopAutoPolling,
                            child: Text(
                              '停止',
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_autoPollingEnabled) const SizedBox(height: 24),

                // 操作说明卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '操作说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(AppLocalizations.of(context).xboardQrPayStep1),
                        Text(AppLocalizations.of(context).xboardQrPayStep2),
                        Text(AppLocalizations.of(context).xboardQrPayStep3),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '提示：如果您无法扫描，可以复制二维码数据',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _copyQRCode,
                        icon: const Icon(Icons.copy),
                        label:
                            Text(AppLocalizations.of(context).xboardCopyQrCode),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isCheckingPayment ? null : _checkPaymentStatus,
                        icon: _isCheckingPayment
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isCheckingPayment ? '检查中...' : '检查状态'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
