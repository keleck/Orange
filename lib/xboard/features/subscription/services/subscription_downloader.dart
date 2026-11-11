import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_clash/clash/core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/infrastructure/http/user_agent_config.dart';
import 'package:fl_clash/xboard/utils/url_masker.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:fl_clash/xboard/features/subscription/utils/utils.dart';

// 初始化文件级日志器
final _logger = FileLogger('subscription_downloader.dart');

/// XBoard 订阅下载服务
/// 
/// 并发下载（直连 + 所有代理），第一个成功就获胜
/// 支持订阅下载失败时自动切换 API 链接
class SubscriptionDownloader {
  static const Duration _downloadTimeout = Duration(seconds: 30);
  
  /// 下载订阅并返回 Profile（并发竞速）
  /// 
  /// [url] 订阅URL
  /// [enableRacing] 是否启用竞速（默认 true，false时只使用直连）
  /// [autoSwitchApi] 是否在失败时自动切换API链接（默认 true）
  /// [useLocalProxy] 是否通过本地内核（上次连接的节点）拉取订阅
  static Future<Profile> downloadSubscription(
    String url, {
    bool enableRacing = true,
    bool autoSwitchApi = true,
    bool useLocalProxy = false,
  }) async {
    try {
      // 确保 URL 有协议前缀
      final normalizedUrl = _ensureProtocol(url);
      _logger.info('原始URL: ${UrlMasker.mask(url)}');
      _logger.info('规范化URL: ${UrlMasker.mask(normalizedUrl)}');
      _logger.info('开始下载订阅: ${UrlMasker.mask(normalizedUrl)}');      
      // 尝试使用当前 URL 下载
      try {
        return await _downloadWithUrl(
          normalizedUrl,
          enableRacing: enableRacing,
          useLocalProxy: useLocalProxy,
        );
      } catch (e) {
        _logger.warning('使用当前URL下载失败: $e');
        
        // 如果启用了自动切换API且当前URL失败，尝试切换到其他API
        if (autoSwitchApi) {
          _logger.info('🔄 开始尝试切换到其他API链接...');
          final alternativeUrl = await _getAlternativeSubscriptionUrl(normalizedUrl);
          
          if (alternativeUrl != null && alternativeUrl != normalizedUrl) {
            _logger.info('✅ 找到备用API链接: ${UrlMasker.mask(alternativeUrl)}');
            _logger.info('🔄 使用备用API重新下载订阅...');
            
            try {
              return await _downloadWithUrl(
                alternativeUrl,
                enableRacing: enableRacing,
                useLocalProxy: useLocalProxy,
              );
            } catch (e2) {
              _logger.error('使用备用API下载也失败: $e2');
              throw Exception('所有API链接都下载失败。原始错误: $e, 备用API错误: $e2');
            }
          } else {
            _logger.warning('⚠️ 没有找到可用的备用API链接');
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      
    } on TimeoutException catch (e) {
      _logger.error('订阅下载超时', e);
      throw Exception('下载超时: ${e.message}');
    } on SocketException catch (e) {
      _logger.error('网络连接失败', e);
      throw Exception('网络连接失败: ${e.message}');
    } on HttpException catch (e) {
      _logger.error('HTTP请求失败', e);
      throw Exception('HTTP请求失败: ${e.message}');
    } catch (e) {
      _logger.error('订阅下载失败', e);
      rethrow;
    }
  }
  
  /// 本地内核的 socks5 入口（mixed-port 同时兼容 socks5），
  /// 仅在代理正在运行时返回，否则返回 null（说明没有可用的「上次连接节点」）。
  static String? _localProxyUrl() {
    if (globalState.appState.runTime == null) return null;
    final port = globalState.config.patchClashConfig.mixedPort;
    if (port <= 0) return null;
    return 'socks5://127.0.0.1:$port';
  }

  /// 使用指定URL下载订阅
  ///
  /// [useLocalProxy] 为 true 时，额外用本地内核的 mixed-port
  /// （即「上次连接的节点」）作为一条下载路径参与竞速。
  static Future<Profile> _downloadWithUrl(
    String url, {
    required bool enableRacing,
    bool useLocalProxy = false,
  }) async {
    final _DownloadResult result;
    final localProxyUrl = useLocalProxy ? _localProxyUrl() : null;
    if (useLocalProxy && localProxyUrl == null) {
      _logger.info('已开启「通过代理更新订阅」，但内核未运行，本次仍走直连');
    } else if (localProxyUrl != null) {
      _logger.info('已开启「通过代理更新订阅」，本地代理: $localProxyUrl');
    }

    if (!enableRacing) {
      // 禁用竞速：优先用本地代理（如果可用），否则直连
      if (localProxyUrl != null) {
        result = await _downloadWithMethod(
          url,
          useProxy: true,
          proxyUrl: localProxyUrl,
          cancelToken: _CancelToken(),
          taskIndex: 0,
        );
      } else {
        _logger.info('竞速已禁用，使用直连下载');
        result = await _downloadWithMethod(
          url,
          useProxy: false,
          cancelToken: _CancelToken(),
          taskIndex: 0,
        );
      }
    } else {
      // 启用竞速：并发下载，第一个成功就获胜
      final proxies = [
        if (localProxyUrl != null) localProxyUrl,
        ...XBoardConfig.allProxyUrls,
      ];
      _logger.info('开始并发下载 (${proxies.length + 1}种方式)');
      
      final cancelTokens = <_CancelToken>[];
      final tasks = <Future<_DownloadResult>>[];
      
      try {
        // 任务0: 直连下载
        final directToken = _CancelToken();
        cancelTokens.add(directToken);
        tasks.add(_downloadWithMethod(
          url,
          useProxy: false,
          cancelToken: directToken,
          taskIndex: 0,
        ));
        
        // 任务1+: 所有代理下载（含本地节点代理）
        for (int i = 0; i < proxies.length; i++) {
          final proxyToken = _CancelToken();
          cancelTokens.add(proxyToken);
          tasks.add(_downloadWithMethod(
            url,
            useProxy: true,
            proxyUrl: proxies[i],
            cancelToken: proxyToken,
            taskIndex: i + 1,
          ));
        }
        
        // 等待第一个成功的任务（忽略失败的）
        result = await _waitForFirstSuccess(tasks);
        
        // 取消其他所有任务
        _logger.info('🏆 ${result.connectionType} 获胜！');
        for (final token in cancelTokens) {
          token.cancel();
        }
        
      } catch (e) {
        // 取消所有任务
        for (final token in cancelTokens) {
          token.cancel();
        }
        rethrow;
      }
    }
    
    // 尝试转换订阅格式（支持节点链接列表和YAML）
    _logger.info('处理订阅内容...');
    String content = result.content;
    
    if (content.trim().isEmpty) {
      throw Exception('下载的内容为空');
    }
    
    // 先尝试直接验证（可能已经是有效的YAML）
    final directValidation = await clashCore.validateConfig(content);
    if (directValidation.isNotEmpty) {
      // 不是有效的YAML，尝试转换节点链接格式
      _logger.info('内容不是标准YAML格式，尝试转换节点链接...');
      final convertedContent = await clashCore.convertSubscription(content);
      if (convertedContent.isEmpty) {
        throw Exception('配置验证失败: $directValidation');
      }
      content = convertedContent;
      _logger.info('✅ 节点链接转换成功');
      
      // 验证转换后的内容
      final convertedValidation = await clashCore.validateConfig(content);
      if (convertedValidation.isNotEmpty) {
        throw Exception('转换后配置验证失败: $convertedValidation');
      }
    }
    _logger.info('✅ 订阅配置验证通过');
    
    // 创建并保存 Profile
    final profile = Profile.normal(url: url);
    final savedProfile = await profile.saveFileWithString(content);
    
    // 更新订阅信息
    final finalProfile = savedProfile.copyWith(
      label: result.label ?? savedProfile.id,
      subscriptionInfo: result.subscriptionInfo,
      lastUpdateDate: DateTime.now(),
    );
    
    _logger.info('✅ 订阅下载成功: ${finalProfile.label}');
    return finalProfile;
  }
  
  /// 获取备用的订阅URL（切换到不同的API域名）
  /// 
  /// 从配置中获取所有订阅API链接，选择一个与当前URL不同的链接
  static Future<String?> _getAlternativeSubscriptionUrl(String currentUrl) async {
    try {
      // 从当前URL提取token
      final token = SubscriptionUrlHelper.extractTokenFromUrl(currentUrl);
      if (token == null) {
        _logger.warning('无法从URL中提取token: ${UrlMasker.mask(currentUrl)}');
        return null;
      }
      
      // 获取所有订阅配置
      final subscriptionConfigs = XBoardConfig.subscriptionUrlList;
      if (subscriptionConfigs.isEmpty) {
        _logger.warning('配置中没有订阅API链接');
        return null;
      }
      
      _logger.info('找到 ${subscriptionConfigs.length} 个订阅API配置');
      
      // 解析当前URL的基础域名
      final currentUri = Uri.parse(currentUrl);
      final currentBase = '${currentUri.scheme}://${currentUri.host}';
      
      // 查找不同的API链接
      for (final config in subscriptionConfigs) {
        final configBase = _ensureProtocol(config.url);
        
        // 跳过与当前URL相同的API
        if (configBase == currentBase || currentUrl.startsWith(configBase)) {
          _logger.debug('跳过当前API: ${config.description}');
          continue;
        }
        
        // 构建新的订阅URL
        // 假设使用 v2 端点
        if (config.endpoints.containsKey('v2')) {
          final endpoint = config.endpoints['v2']!;
          final path = endpoint.path.replaceAll('{token}', token);
          final normalizedConfigBase = configBase.endsWith('/') ? configBase.substring(0, configBase.length - 1) : configBase;
          final normalizedPath = path.startsWith('/') ? path : '/$path';
          final newUrl = '$normalizedConfigBase$normalizedPath';
          
          _logger.info('✅ 选择备用API: ${config.description} - ${UrlMasker.mask(newUrl)}');
          return newUrl;
        }
      }
      
      _logger.warning('没有找到可用的备用API链接');
      return null;
      
    } catch (e) {
      _logger.error('获取备用订阅URL失败', e);
      return null;
    }
  }
  
  /// 确保URL包含协议前缀
  static String _ensureProtocol(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // 默认使用 https://
    return 'https://$url';
  }
  
  /// 等待第一个成功的任务（忽略失败的）
  static Future<_DownloadResult> _waitForFirstSuccess(
    List<Future<_DownloadResult>> tasks,
  ) async {
    final completer = Completer<_DownloadResult>();
    int failedCount = 0;
    final errors = <Object>[];
    
    for (final task in tasks) {
      task.then((result) {
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }).catchError((e) {
        failedCount++;
        errors.add(e);
        
        // 如果所有任务都失败了，抛出第一个错误
        if (failedCount == tasks.length && !completer.isCompleted) {
          _logger.error('所有下载任务都失败了', errors.first);
          completer.completeError(errors.first);
        }
      });
    }
    
    return completer.future;
  }
  
  /// 使用指定方式下载完整订阅内容
  static Future<_DownloadResult> _downloadWithMethod(
    String url, {
    required bool useProxy,
    String? proxyUrl,
    required _CancelToken cancelToken,
    required int taskIndex,
  }) async {
    final connectionType = useProxy ? '代理($proxyUrl)' : '直连';
    _logger.info('[任务$taskIndex] 开始下载: $connectionType');
    
    // 对单个下载任务添加内部重试机制
    const int internalRetries = 3;
    Exception? lastError;
    
    for (int attempt = 1; attempt <= internalRetries; attempt++) {
      try {
        final result = await _downloadWithProxy(
          url,
          useProxy: useProxy,
          proxyUrl: proxyUrl,
          cancelToken: cancelToken,
        );
        
        _logger.info('[任务$taskIndex] 下载成功 (第$attempt次): $connectionType，大小: ${result.bytes.length} bytes');
        
        return _DownloadResult(
          content: result.content,
          connectionType: connectionType,
          label: result.label,
          subscriptionInfo: result.subscriptionInfo,
          bytes: result.bytes,
        );
        
      } catch (e) {
        if (cancelToken.isCancelled) {
          _logger.info('[任务$taskIndex] 已取消: $connectionType');
          rethrow;
        } else {
          _logger.warning('[任务$taskIndex] 下载失败 (尝试$attempt/$internalRetries): $connectionType - $e');
          lastError = e is Exception ? e : Exception(e.toString());
          
          if (attempt < internalRetries) {
            // 等待后重试
            _logger.info('[任务$taskIndex] 等待1秒后重试...');
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
    }
    
    // 所有重试都失败了，抛出最后的错误
    throw lastError ?? Exception('下载失败');
  }
  
  /// 使用代理下载订阅内容
  static Future<_DownloadRawResult> _downloadWithProxy(
    String url, {
    required bool useProxy,
    String? proxyUrl,
    required _CancelToken cancelToken,
  }) async {
    HttpClient? client;
    
    try {
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        throw Exception('任务已取消');
      }
      
      // 创建 HttpClient
      client = HttpClient();
      client.connectionTimeout = _downloadTimeout;
      client.badCertificateCallback = (cert, host, port) => true;
      
      // 如果使用代理，配置 SOCKS5 代理
      if (useProxy && proxyUrl != null) {
        final proxyConfig = _parseProxyConfig(proxyUrl);
        final proxySettings = ProxySettings(
          InternetAddress(proxyConfig['host']!),
          int.parse(proxyConfig['port']!),
          username: proxyConfig['username'],
          password: proxyConfig['password'],
        );
        
        SocksTCPClient.assignToHttpClient(client, [proxySettings]);
      }
      
      // 发起请求
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }
      
      // 设置请求头
      final userAgent = await UserAgentConfig.get(UserAgentScenario.subscription);
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }
      
      // 获取响应
      final response = await request.close().timeout(
        _downloadTimeout,
        onTimeout: () {
          throw TimeoutException('下载超时', _downloadTimeout);
        },
      );
      
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }
      
      // 读取响应内容
      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) {
          if (cancelToken.isCancelled) {
            throw Exception('任务已取消');
          }
          return previous..addAll(element);
        },
      );
      final content = utf8.decode(bytes);
      
      // 解析响应头
      final disposition = response.headers.value('content-disposition');
      final userinfo = response.headers.value('subscription-userinfo');
      
      String? label;
      if (disposition != null) {
        // 从 content-disposition 提取文件名
        final match = RegExp(r'filename="?([^";\n]+)"?').firstMatch(disposition);
        if (match != null) {
          label = match.group(1)?.trim();
        }
      }
      
      final subscriptionInfo = userinfo != null 
          ? SubscriptionInfo.formHString(userinfo) 
          : null;
      
      return _DownloadRawResult(
        content: content,
        label: label,
        subscriptionInfo: subscriptionInfo,
        bytes: bytes,
      );
      
    } finally {
      if (cancelToken.isCancelled) {
        client?.close(force: true);
      } else {
        client?.close();
      }
    }
  }
  
  /// 解析代理配置
  ///
  /// 输入格式:
  /// - `socks5://user:pass@host:port`
  /// - `socks5://host:port`
  /// - `http://user:pass@host:port`
  ///
  /// 返回: { host, port, username?, password? }
  static Map<String, String?> _parseProxyConfig(String proxyUrl) {
    String url = proxyUrl.trim();

    // 去除协议前缀
    if (url.toLowerCase().startsWith('socks5://')) {
      url = url.substring(9);
    } else if (url.toLowerCase().startsWith('http://')) {
      url = url.substring(7);
    } else if (url.toLowerCase().startsWith('https://')) {
      url = url.substring(8);
    }

    String? username;
    String? password;
    String hostPort = url;

    // 解析认证信息 user:pass@host:port
    if (url.contains('@')) {
      final atIndex = url.lastIndexOf('@');
      final authPart = url.substring(0, atIndex);
      hostPort = url.substring(atIndex + 1);

      if (authPart.contains(':')) {
        final colonIndex = authPart.indexOf(':');
        username = authPart.substring(0, colonIndex);
        password = authPart.substring(colonIndex + 1);
      }
    }

    // 解析 host:port
    final colonIndex = hostPort.lastIndexOf(':');
    if (colonIndex == -1) {
      throw FormatException('代理配置格式错误，缺少端口号: $proxyUrl');
    }

    final host = hostPort.substring(0, colonIndex);
    final port = hostPort.substring(colonIndex + 1);

    if (host.isEmpty || port.isEmpty) {
      throw FormatException('代理配置格式错误: $proxyUrl');
    }

    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }
}

/// 取消令牌
class _CancelToken {
  bool _isCancelled = false;
  
  bool get isCancelled => _isCancelled;
  
  void cancel() {
    _isCancelled = true;
  }
}

/// 下载结果（含连接类型）
class _DownloadResult {
  final String content;
  final String connectionType;
  final String? label;
  final SubscriptionInfo? subscriptionInfo;
  final List<int> bytes;
  
  _DownloadResult({
    required this.content,
    required this.connectionType,
    this.label,
    this.subscriptionInfo,
    required this.bytes,
  });
}

/// 下载原始结果
class _DownloadRawResult {
  final String content;
  final String? label;
  final SubscriptionInfo? subscriptionInfo;
  final List<int> bytes;
  
  _DownloadRawResult({
    required this.content,
    this.label,
    this.subscriptionInfo,
    required this.bytes,
  });
}
