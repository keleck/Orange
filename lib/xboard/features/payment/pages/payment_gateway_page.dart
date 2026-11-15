import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/app_colors.dart';

class PaymentGatewayPage extends ConsumerStatefulWidget {
  final String paymentUrl;
  final String tradeNo;
  const PaymentGatewayPage({
    super.key,
    required this.paymentUrl,
    required this.tradeNo,
  });

  @override
  ConsumerState<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends ConsumerState<PaymentGatewayPage> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCheckingPayment = false;
  bool _autoPollingEnabled = false;
  late WebViewController _webViewController;
  win.WebviewController? _winWebViewController; // Windows 原生 WebView 控制器
  Timer? _pollingTimer;
  bool _isWebViewInitialized = false; // 追踪WebView初始化状态
  bool _isUsingWindowsWebView = false; // 标记是否使用 Windows 原生 WebView

  @override
  void initState() {
    super.initState();
    debugPrint('[PaymentGateway] ===== 页面初始化 ===== TradeNo: ${widget.tradeNo}');
    // Windows 平台使用原生 WebView 初始化
    if (Platform.isWindows) {
      _initializeWindowsWebView();
    } else {
      _initializeWebViewPlatform();
      _initializeWebView();
    }
    _startPaymentStatusCheck();
  }

  @override
  void dispose() {
    debugPrint('[PaymentGateway] ===== 页面销毁 ===== TradeNo: ${widget.tradeNo}');
    debugPrint('[PaymentGateway] 停止轮询标志: $_autoPollingEnabled -> false');
    _autoPollingEnabled = false;
    _isWebViewInitialized = false;
    _winWebViewController?.dispose(); // 清理 Windows WebView
    if (_pollingTimer != null) {
      debugPrint('[PaymentGateway] 取消定时器');
      _pollingTimer?.cancel();
    }
    super.dispose();
  }

  Future<void> _initializeWindowsWebView() async {
    debugPrint('[PaymentGateway] 初始化 Windows 原生 WebView');
    if (widget.paymentUrl.isEmpty) {
      debugPrint('[PaymentGateway] URL 为空，无法加载');
      if (mounted) {
        setState(() {
          _errorMessage = '支付 URL 为空，无法加载支付页面';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final controller = win.WebviewController();
      await controller.initialize();

      debugPrint('[PaymentGateway] Windows WebView 初始化成功');

      // 设置背景透明（可选）
      await controller.setBackgroundColor(Colors.transparent);

      // 加载 URL
      await controller.loadUrl(widget.paymentUrl);

      debugPrint('[PaymentGateway] Windows WebView 开始加载: ${widget.paymentUrl}');

      // 监听加载完成
      controller.loadingState.listen((state) {
        if (state == win.LoadingState.navigationCompleted) {
          debugPrint('[PaymentGateway] Windows WebView 页面加载完成');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                XBoardNotification.showInfo('支付页面已加载');
              }
            });
          }
          _startAutoPolling();
        }
      });

      if (!mounted) return;

      setState(() {
        _winWebViewController = controller;
        _isUsingWindowsWebView = true;
        _isWebViewInitialized = true;
        _isLoading = false;
      });

      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          XBoardNotification.showInfo('正在加载支付页面...');
        }
      });
    } catch (e) {
      debugPrint('[PaymentGateway] Windows WebView 初始化失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Windows WebView 初始化失败: $e';
          _isLoading = false;
          _isWebViewInitialized = false;
        });
      }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          XBoardNotification.showError('Windows WebView 初始化失败: $e');
        }
      });
    }
  }

  void _initializeWebViewPlatform() {
    debugPrint('[PaymentGateway] 检查 WebView Platform');
    try {
      // WebView 平台初始化检查
      // webview_flutter 在 Windows 上的平台实现由 Flutter 引擎自动提供
      final platformInstance = WebViewPlatform.instance;
      if (platformInstance != null) {
        debugPrint(
            '[PaymentGateway] WebViewPlatform 已初始化: ${platformInstance.runtimeType}');
      } else {
        debugPrint(
            '[PaymentGateway] 警告: WebViewPlatform 为 null - 这可能导致 WebView 初始化失败');
      }
    } catch (e) {
      debugPrint('[PaymentGateway] WebView Platform 检查异常: $e');
    }
  }

  void _initializeWebView() {
    debugPrint('[PaymentGateway] 初始化 WebView - URL: ${widget.paymentUrl}');
    // 检查 URL 有效性
    if (widget.paymentUrl.isEmpty) {
      debugPrint('[PaymentGateway] URL 为空，无法加载');
      setState(() {
        _errorMessage = '支付 URL 为空，无法加载支付页面';
        _isLoading = false;
      });
      return;
    }

    try {
      debugPrint('[PaymentGateway] 创建 WebViewController');
      debugPrint('[PaymentGateway] 平台: ${Platform.operatingSystem}');
      debugPrint(
          '[PaymentGateway] WebViewPlatform.instance: ${WebViewPlatform.instance}');

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted);

      // 只在Android和iOS上设置背景色，macOS不支持
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          controller.setBackgroundColor(AppColors.fg(context));
          debugPrint('[PaymentGateway] 设置WebView背景色');
        } catch (e) {
          debugPrint('[PaymentGateway] 设置背景色失败（非关键）: $e');
        }
      }

      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('[PaymentGateway] 页面开始加载 - URL: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            debugPrint('[PaymentGateway] 页面加载完成 - URL: $url');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            if (mounted) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  XBoardNotification.showInfo('支付页面已加载');
                }
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
                '[PaymentGateway] WebView 资源错误 - Type: ${error.errorType}, Code: ${error.errorCode}, Description: ${error.description}');
            // 只在主资源加载失败时显示错误，忽略子资源错误
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _errorMessage =
                      '加载失败: ${error.description}\n错误代码: ${error.errorCode}';
                  _isLoading = false;
                });
              }
              if (mounted) {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    XBoardNotification.showError(
                        '加载支付页面失败: ${error.description}');
                  }
                });
              }
            } else {
              debugPrint('[PaymentGateway] 忽略子资源错误');
            }
          },
          onHttpError: (HttpResponseError error) {
            debugPrint(
                '[PaymentGateway] HTTP 错误 - StatusCode: ${error.response?.statusCode}');
            if (mounted) {
              setState(() {
                _errorMessage = 'HTTP 错误 ${error.response?.statusCode}';
                _isLoading = false;
              });
            }
            if (mounted) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  XBoardNotification.showError(
                      'HTTP 错误: ${error.response?.statusCode}');
                }
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('[PaymentGateway] 导航请求 - URL: ${request.url}');

            // 检查是否是特殊的URL scheme
            final uri = Uri.parse(request.url);
            final scheme = uri.scheme.toLowerCase();

            // 支付相关的URL scheme列表
            final paymentSchemes = [
              'alipay', // 支付宝
              'alipays', // 支付宝安全协议
              'weixin', // 微信
              'wechat', // 微信
              'mqqapi', // QQ
              'mqq', // QQ
              'unionpay', // 银联
              'uppaywallet', // 银联钱包
              'baiduboxapp', // 百度
              'sinaweibo', // 微博
              'taobao', // 淘宝
              'tmall', // 天猫
              'jdmobile', // 京东
              'pinduoduo', // 拼多多
              'suning', // 苏宁
              'openapp.jdmobile', // 京东
              'tbopen', // 淘宝开放平台
            ];

            if (paymentSchemes.contains(scheme)) {
              debugPrint('[PaymentGateway] 检测到支付应用URL scheme: $scheme');

              // 尝试启动外部应用
              _launchExternalApp(request.url);

              // 阻止WebView导航，因为我们要用外部应用处理
              return NavigationDecision.prevent;
            }

            // 对于普通的HTTP/HTTPS链接，允许导航
            if (scheme == 'http' || scheme == 'https') {
              return NavigationDecision.navigate;
            }

            // 对于其他未知scheme，尝试启动外部应用
            if (scheme != 'about' && scheme != 'data') {
              debugPrint('[PaymentGateway] 检测到未知URL scheme: $scheme，尝试启动外部应用');
              _launchExternalApp(request.url);
              return NavigationDecision.prevent;
            }

            // 默认允许导航
            return NavigationDecision.navigate;
          },
        ),
      );

      // Android特定配置
      if (Platform.isAndroid) {
        debugPrint('[PaymentGateway] 应用Android特定配置');

        try {
          controller.enableZoom(true);
          debugPrint('[PaymentGateway] 启用缩放功能');
        } catch (e) {
          debugPrint('[PaymentGateway] 启用缩放失败（非关键）: $e');
        }

        // 使用反射方式配置Android WebView，避免直接依赖
        try {
          final platform = controller.platform;
          if (platform != null) {
            // 通过反射调用Android特定方法
            final platformType = platform.runtimeType.toString();
            debugPrint('[PaymentGateway] WebView平台类型: $platformType');

            // 尝试设置媒体播放和混合内容模式
            if (platformType.contains('Android')) {
              // 这些方法在webview_flutter 4.13.0中已经包含
              // setMediaPlaybackRequiresUserGesture 和 setMixedContentMode
              // 会自动通过platform调用
              debugPrint('[PaymentGateway] Android WebView配置已应用');
            }
          }
        } catch (e) {
          debugPrint('[PaymentGateway] Android特定配置失败（非关键）: $e');
        }
      }

      // 在赋值前检查mounted，避免在页面被销毁时赋值
      if (!mounted) {
        debugPrint('[PaymentGateway] 初始化时页面已销毁，跳过');
        return;
      }

      // 赋值给late变量
      _webViewController = controller;

      // 标记WebView已初始化
      _isWebViewInitialized = true;

      // 加载请求
      _webViewController.loadRequest(Uri.parse(widget.paymentUrl));

      debugPrint(
          '[PaymentGateway] WebView 开始加载请求 - TradeNo: ${widget.tradeNo}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startAutoPolling();
        // 延迟显示通知，避免在 build 过程中调用
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            XBoardNotification.showInfo('正在加载支付页面...');
          }
        });
      }
    } catch (e) {
      debugPrint('[PaymentGateway] 初始化失败 - Error: $e');
      _isWebViewInitialized = false;
      if (mounted) {
        setState(() {
          _errorMessage = '初始化支付页面失败: $e';
          _isLoading = false;
        });
      }
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            XBoardNotification.showError('初始化支付页面失败: $e');
          }
        });
      }
    }
  }

  Future<void> _startPaymentStatusCheck() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _checkPaymentStatus();
    }
  }

  void _startAutoPolling() {
    if (_autoPollingEnabled) {
      debugPrint('[PaymentGateway] 轮询已启动，跳过 - TradeNo: ${widget.tradeNo}');
      return;
    }
    debugPrint('[PaymentGateway] 启动自动轮询 - TradeNo: ${widget.tradeNo}');
    setState(() {
      _autoPollingEnabled = true;
    });
    _pollPaymentStatus();
  }

  void _stopAutoPolling() {
    debugPrint('[PaymentGateway] 停止自动轮询 - TradeNo: ${widget.tradeNo}');
    setState(() {
      _autoPollingEnabled = false;
    });
    if (_pollingTimer != null) {
      debugPrint('[PaymentGateway] 取消定时器');
      _pollingTimer?.cancel();
    }
  }

  Future<void> _pollPaymentStatus() async {
    debugPrint(
        '[PaymentGateway] 轮询检查开始 - TradeNo: ${widget.tradeNo}, 启用状态: $_autoPollingEnabled, mounted: $mounted');
    if (!_autoPollingEnabled || !mounted) {
      debugPrint(
          '[PaymentGateway] 轮询终止 (未启用或已销毁) - TradeNo: ${widget.tradeNo}');
      return;
    }
    await Future.delayed(const Duration(seconds: 5));
    if (!_autoPollingEnabled || !mounted) {
      debugPrint('[PaymentGateway] 延迟后终止轮询 - TradeNo: ${widget.tradeNo}');
      return;
    }
    await _checkPaymentStatus(silent: true);
    if (_autoPollingEnabled && mounted) {
      debugPrint('[PaymentGateway] 创建下次轮询定时器 - TradeNo: ${widget.tradeNo}');
      // 使用 Timer 替代递归调用，确保能够正确取消
      _pollingTimer = Timer(const Duration(seconds: 5), _pollPaymentStatus);
    } else {
      debugPrint('[PaymentGateway] 不再创建新的轮询 - TradeNo: ${widget.tradeNo}');
    }
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_isCheckingPayment) {
      debugPrint('[PaymentGateway] 已在检查支付状态，跳过 - TradeNo: ${widget.tradeNo}');
      return;
    }
    debugPrint(
        '[PaymentGateway] 开始检查支付状态 - TradeNo: ${widget.tradeNo}, silent: $silent');
    setState(() {
      _isCheckingPayment = true;
    });
    try {
      final orderModels = await XBoardSDK.instance.order.getOrders();
      debugPrint('[PaymentGateway] 获取到订单列表，共 ${orderModels.length} 条');
      debugPrint('[PaymentGateway] 获取到订单列表，共 ${orderModels.length} 条');
      final order = orderModels.firstWhere(
        (o) => o.tradeNo == widget.tradeNo,
        orElse: () => const OrderModel(status: -1),
      );
      debugPrint(
          '[PaymentGateway] 查找订单结果 - TradeNo: ${widget.tradeNo}, 状态: ${order.status}');

      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
        });
        if (order.status != -1) {
          if (order.status == 3) {
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
            _stopAutoPolling();
            if (!silent) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  XBoardNotification.showInfo('支付已取消');
                }
              });
            }
          } else if (order.status == 0 || order.status == 1) {
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

  Future<void> _copyPaymentUrl() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.paymentUrl));
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            XBoardNotification.showSuccess('支付链接已复制到剪贴板');
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

  Future<void> _launchExternalApp(String url) async {
    try {
      debugPrint('[PaymentGateway] 尝试启动外部应用: $url');

      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);

      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          debugPrint('[PaymentGateway] 成功启动外部应用');
          if (mounted) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                XBoardNotification.showInfo('已跳转到支付应用，请完成支付');
              }
            });
          }

          // 启动外部应用后，开始更频繁地检查支付状态
          _startFrequentPaymentCheck();
        } else {
          debugPrint('[PaymentGateway] 启动外部应用失败');
          _handleExternalAppLaunchFailed(url);
        }
      } else {
        debugPrint('[PaymentGateway] 无法启动外部应用，可能未安装相关应用');
        _handleExternalAppLaunchFailed(url);
      }
    } catch (e) {
      debugPrint('[PaymentGateway] 启动外部应用异常: $e');
      _handleExternalAppLaunchFailed(url);
    }
  }

  void _handleExternalAppLaunchFailed(String url) {
    if (mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          XBoardNotification.showError('无法打开支付应用，请确保已安装相关应用');
        }
      });
    }
  }

  void _startFrequentPaymentCheck() {
    debugPrint('[PaymentGateway] 启动频繁支付状态检查');
    // 取消现有的轮询
    if (_pollingTimer != null) {
      _pollingTimer?.cancel();
    }

    // 启动更频繁的检查（每2秒一次，持续30秒）
    int checkCount = 0;
    const maxChecks = 15; // 30秒 / 2秒 = 15次

    Timer.periodic(const Duration(seconds: 2), (timer) {
      checkCount++;

      if (!mounted || !_autoPollingEnabled || checkCount > maxChecks) {
        timer.cancel();
        // 恢复正常轮询
        if (mounted && _autoPollingEnabled) {
          _pollPaymentStatus();
        }
        return;
      }

      _checkPaymentStatus(silent: true);
    });
  }

  Future<void> _reloadWebView() async {
    try {
      await _webViewController.reload();
    } catch (e) {
      debugPrint('[PaymentGateway] 刷新WebView失败: $e');
      if (mounted) {
        XBoardNotification.showError('刷新失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
        title: AppLocalizations.of(context).xboardPaymentGateway,
        body: _errorMessage != null
            ? SafeArea(
                child: SingleChildScrollView(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Icon(Icons.error,
                              size: 64, color: Colors.red.shade600),
                          const SizedBox(height: 24),
                          const Text(
                            '加载支付页面失败',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage ?? '未知错误',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _errorMessage = null;
                                      _isLoading = true;
                                      _isWebViewInitialized = false;
                                      _isUsingWindowsWebView = false;
                                    });
                                    if (Platform.isWindows) {
                                      _initializeWindowsWebView();
                                    } else {
                                      _initializeWebView();
                                    }
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: Text(
                                      AppLocalizations.of(context).xboardRetry),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: AppColors.fg(context),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back),
                                  label: Text(
                                      AppLocalizations.of(context).xboardBack),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    foregroundColor: AppColors.fg(context),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
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
              )
            : SafeArea(
                child: _isWebViewInitialized
                    ? Stack(
                        children: [
                          // WebView 显示支付页面 - 占满整个可用空间
                          if (Platform.isWindows &&
                              _isUsingWindowsWebView &&
                              _winWebViewController != null)
                            Positioned.fill(
                              child: win.Webview(_winWebViewController!),
                            )
                          else
                            Positioned.fill(
                              child:
                                  WebViewWidget(controller: _webViewController),
                            ),

                          // 加载指示器
                          if (_isLoading)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.3),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),

                          // 悬浮操作面板
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 状态卡片
                                if (_autoPollingEnabled)
                                  Card(
                                    color: Colors.green.shade50,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.green.shade600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '自动检测支付状态',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.green.shade800,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  '系统每5秒检查一次',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.green.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _stopAutoPolling,
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                            ),
                                            child: Text(
                                              '停止',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_autoPollingEnabled)
                                  const SizedBox(height: 8),

                                // 操作按钮
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _reloadWebView,
                                        icon:
                                            const Icon(Icons.refresh, size: 18),
                                        label: Text(AppLocalizations.of(context)
                                            .xboardRefresh),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor:
                                              AppColors.fg(context),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        onPressed: _copyPaymentUrl,
                                        icon: const Icon(Icons.copy, size: 18),
                                        label: Text(AppLocalizations.of(context)
                                            .copyLink),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purple,
                                          foregroundColor:
                                              AppColors.fg(context),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        onPressed: _isCheckingPayment
                                            ? null
                                            : _checkPaymentStatus,
                                        icon: _isCheckingPayment
                                            ? SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    AppColors.fg(context),
                                                  ),
                                                ),
                                              )
                                            : const Icon(Icons.check, size: 18),
                                        label: Text(
                                          _isCheckingPayment ? '检查中' : '检查状态',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor:
                                              AppColors.fg(context),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context)
                                .xboardInitializingPayment),
                          ],
                        ),
                      ),
              ));
  }
}
