import 'dart:io';

import 'package:crisp_chat/crisp_chat.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'package:fl_clash/widgets/app_colors.dart';

/// Crisp 在线客服页面
class CrispSupportPage extends ConsumerStatefulWidget {
  const CrispSupportPage({super.key});

  @override
  ConsumerState<CrispSupportPage> createState() => _CrispSupportPageState();
}

class _CrispSupportPageState extends ConsumerState<CrispSupportPage> {
  bool _isChatOpened = false;
  String? _errorMessage;
  WebViewController? _webViewController;
  win.WebviewController? _winWebViewController;
  bool _isWebViewSupported = false;

  /// 获取 Crisp 网站 ID（从远程配置）
  String? get _websiteId => XBoardConfig.crispWebsiteId;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get _isWindows => Platform.isWindows;

  @override
  void initState() {
    super.initState();
    
    // 如果是桌面端(macOS)，初始化 WebView
    if (Platform.isMacOS) {
      _isWebViewSupported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initWebView();
      });
    } else if (_isWindows) {
      _isWebViewSupported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initWindowsWebView();
      });
    } else if (_isMobile) {
      // 移动端：延迟打开原生 SDK 聊天窗口
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCrispChat();
      });
    } else {
      // Linux 暂不支持内嵌
      _isWebViewSupported = false;
    }
  }

  Future<void> _initWindowsWebView() async {
    final websiteId = _websiteId;
    if (websiteId == null || websiteId.isEmpty) {
      setState(() {
        _errorMessage = '客服系统配置未找到，请稍后重试';
      });
      return;
    }

    try {
      final controller = win.WebviewController();
      await controller.initialize();
      
      await controller.setBackgroundColor(Colors.transparent);
      await controller.loadUrl('https://go.crisp.chat/chat/embed/?website_id=$websiteId');
      
      // 监听加载完成，注入用户信息
      controller.loadingState.listen((state) {
        if (state == win.LoadingState.navigationCompleted) {
          _injectWindowsUserInfo(controller);
        }
      });

      if (!mounted) return;
      
      setState(() {
        _winWebViewController = controller;
      });
    } catch (e) {
      debugPrint('Windows WebView init error: $e');
      // 如果初始化失败（如缺少运行时），降级显示
      if (mounted) {
        setState(() {
          _isWebViewSupported = false;
        });
      }
    }
  }

  void _injectWindowsUserInfo(win.WebviewController controller) {
    final userState = ref.read(xboardUserProvider);
    final userInfo = userState.userInfo;
    if (userInfo != null && userState.email != null) {
      final email = userState.email!;
      final nickname = email.split('@').first;
      
      controller.executeScript('''
        if (window.\$crisp) {
          \$crisp.push(["set", "user:email", ["$email"]]);
          \$crisp.push(["set", "user:nickname", ["$nickname"]]);
        }
      ''');
    }
  }

  Future<void> _initWebView() async {
    final websiteId = _websiteId;
    if (websiteId == null || websiteId.isEmpty) {
      setState(() {
        _errorMessage = '客服系统配置未找到，请稍后重试';
      });
      return;
    }

    // 初始化 WebView Controller
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _injectUserInfo(controller);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$websiteId'));

    setState(() {
      _webViewController = controller;
    });
  }

  void _injectUserInfo(WebViewController controller) {
    final userState = ref.read(xboardUserProvider);
    final userInfo = userState.userInfo;
    if (userInfo != null && userState.email != null) {
      final email = userState.email!;
      final nickname = email.split('@').first;
      
      // 注入用户信息到 Crisp
      controller.runJavaScript('''
        if (window.\$crisp) {
          \$crisp.push(["set", "user:email", ["$email"]]);
          \$crisp.push(["set", "user:nickname", ["$nickname"]]);
        }
      ''');
    }
  }

  Future<void> _openCrispChat() async {
    if (_isChatOpened) return;

    final websiteId = _websiteId;
    if (websiteId == null || websiteId.isEmpty) {
      setState(() {
        _errorMessage = '客服系统配置未找到，请稍后重试';
      });
      return;
    }

    // 获取用户信息
    final userState = ref.read(xboardUserProvider);
    final userInfo = userState.userInfo;

    final config = CrispConfig(
      websiteID: websiteId,
    );

    if (userInfo != null && userState.email != null) {
      config.user = User(
        email: userState.email!,
        nickName: userState.email!.split('@').first,
      );
      config.sessionSegment = 'app-user';
    }

    setState(() {
      _isChatOpened = true;
      _errorMessage = null;
    });

    try {
      await FlutterCrispChat.openCrispChat(config: config);
    } catch (e) {
      debugPrint('Crisp Chat Error: $e');
      if (mounted) {
         // 在这里不显示SnackBar，由UI层提示
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _launchBrowserChat() async {
    final websiteId = _websiteId;
    if (websiteId != null && websiteId.isNotEmpty) {
      final url = Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$websiteId');
      if (!await launchUrl(url)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开浏览器')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _winWebViewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);

    Widget content;

    if (_errorMessage != null) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回'),
            ),
          ],
        ),
      );
    } else if (Platform.isMacOS) {
      if (_webViewController != null) {
        content = Padding(
          padding: const EdgeInsets.only(bottom: 100), // 添加底部 padding 避免被导航栏遮挡
          child: WebViewWidget(controller: _webViewController!),
        );
      } else {
        content = const Center(child: CircularProgressIndicator());
      }
    } else if (_isWindows && _isWebViewSupported) {
      if (_winWebViewController != null) {
        content = Padding(
          padding: const EdgeInsets.only(bottom: 100), // 添加底部 padding 避免被导航栏遮挡
          child: win.Webview(_winWebViewController!),
        );
      } else {
        content = const Center(child: CircularProgressIndicator());
      }
    } else if (_isMobile) {
       content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在打开客服窗口...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openCrispChat,
              icon: const Icon(Icons.support_agent),
              label: Text(appLocalizations.onlineSupport),
            ),
          ],
        ),
      );
    } else {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.web, size: 64),
            const SizedBox(height: 16),
             Text(
              '当前平台暂不支持内嵌客服窗口',
               style: Theme.of(context).textTheme.headlineSmall,
            ),
             const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _launchBrowserChat,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('在浏览器中打开'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: AppColors.getBackgroundDecoration(),
      child: Column(
        children: [
          // 固定的 AppBar
          AppBar(
            title: Text(appLocalizations.onlineSupport),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
          ),
          // 内容区域
          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }
}
