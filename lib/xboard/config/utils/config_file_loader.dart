import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import '../core/config_settings.dart';
import '../../core/core.dart';
import 'url_cipher.dart';

// 初始化文件级日志器
final _logger = FileLogger('config_file_loader.dart');

/// 配置文件加载器
/// 
/// 从 assets/config/xboard.config.yaml 加载 XBoard 配置
class ConfigFileLoader {
  /// 配置文件路径
  static const String configPath = 'assets/config/xboard.config.yaml';
  
  /// 加密的远程配置源列表
  /// 
  /// 包含多个已加密的远程 URL，使用 XOR + HMAC-SHA256 加密
  /// 防止在反编译时直接暴露，生产部署时应使用构建时注入的加密密钥
  /// 格式：(name: 源名称, encryptedUrl: 加密URL, priority: 优先级)
  static const List<({String name, String encryptedUrl, int priority})> encryptedRemoteSources = [
    (name: 'redirect', encryptedUrl: 'CeLpWHfIgRtNEc0z+8fR6mB+f3x+NCA/Y3NkOnJ/Y3t2fn4yfnFyD0pHT0FGTQhcY2JhemR+IGJwZTx5dH95N2t/dnNpezFDTkxFTUIITVtnZET4Q7y96fbo7P3OFzaKmBeAZznB4aR32lOlrbP0bPnd', priority: 100),
    // (name: 'redirect-2', encryptedUrl: 'PrX6v/3cDA85G7BQW5Ole2B+f3x+NCA/ZmVkOm14OjUgcWplLCh9FlJEDUpAUghLZ2RtZWogZWN+fIgDDgWxeAGVRjsOCAora4mtddkUx08dkIn+eqrVdQ7N', priority: 100),
    // 可以添加更多源：
    // (name: 'redirect-3', encryptedUrl: '...', priority: 80),
    // (name: 'redirect-4', encryptedUrl: '...', priority: 70),
  ];
  
  /// 加密密钥（应从环境变量或安全存储读取）
  /// 
  /// 使用 `openssl rand -base64 32` 生成新密钥，或使用 UrlCipher.generateEncryptionKey()
  static String? _encryptionKey;
  
  /// 内嵌的远程配置源（敏感 URL 打包到客户端，防止暴露）
  /// URL 已加密，使用 UrlCipher 在启动时解密
  static final List<RemoteSourceConfig> _builtInRemoteSources = 
    encryptedRemoteSources.map((source) => 
      RemoteSourceConfig(
        name: source.name,
        url: source.encryptedUrl,
        priority: source.priority,
        isEncrypted: true,
      )).toList();
  
  /// 设置加密密钥
  /// 
  /// 在应用启动时调用此方法设置加密密钥
  /// 建议从环境变量、构建参数或安全存储读取
  static void setEncryptionKey(String key) {
    if (UrlCipher.isValidKey(key)) {
      _encryptionKey = key;
      _logger.info('加密密钥已设置');
    } else {
      _logger.warning('无效的加密密钥格式（应为 32 字节 Base64 编码）');
    }
  }
  
  /// 对URL进行打码处理（用于日志输出）
  /// 
  /// 保留协议、域名和路径开头，隐藏中间敏感部分
  static String _maskUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final scheme = uri.scheme;
      final host = uri.host;
      final path = uri.path;
      
      // 如果路径较短，直接显示
      if (path.length <= 10) {
        return '$scheme://$host$path';
      }
      
      // 路径较长时，只显示开头和结尾
      final pathStart = path.substring(0, 5);
      final pathEnd = path.substring(path.length - 5);
      final maskedPath = '$pathStart***$pathEnd';
      
      return '$scheme://$host$maskedPath';
    } catch (e) {
      // 解析失败时返回通用打码
      return '***URL已打码***';
    }
  }
  
  /// 对密钥进行打码处理（用于日志输出）
  /// 
  /// 只显示开头和结尾字符，隐藏中间敏感部分
  static String _maskKey(String key) {
    if (key.length <= 8) {
      return '***';
    }
    
    final start = key.substring(0, 4);
    final end = key.substring(key.length - 4);
    return '$start***$end';
  }

  /// 加载配置文件
  /// 
  /// 从 assets/config/xboard.config.yaml 加载配置
  /// 如果 YAML 中的远程配置源为空，则使用内嵌的默认源
  static Future<ConfigSettings> loadFromFile() async {
    try {
      final yamlString = await rootBundle.loadString(configPath);
      var config = _parseYamlString(yamlString);
      
      // 如果配置文件中的远程源为空，使用内嵌的默认源
      if (config.remoteConfig.sources.isEmpty) {
        final sources = await _prepareRemoteSources();
        config = ConfigSettings(
          currentProvider: config.currentProvider,
          remoteConfig: RemoteConfigSettings(
            sources: sources,
            maxRetries: config.remoteConfig.maxRetries,
            timeout: config.remoteConfig.timeout,
            retryDelay: config.remoteConfig.retryDelay,
          ),
          subscription: config.subscription,
          log: config.log,
        );
        _logger.info('使用内嵌的远程配置源');
      }
      
      _logger.info('从 assets 加载配置: $configPath');
      return config;
    } catch (e) {
      _logger.error('加载配置文件失败', e);
      return const ConfigSettings();
    }
  }
  
  /// 准备远程配置源（处理加密 URL）
  static Future<List<RemoteSourceConfig>> _prepareRemoteSources() async {
    final sources = <RemoteSourceConfig>[];
    
    for (final source in _builtInRemoteSources) {
      if (source.isEncrypted && _encryptionKey != null) {
        try {
          // 解密 URL
          final decryptedUrl = UrlCipher.decryptUrl(
            source.url,
            encryptionKey: _encryptionKey,
          );

            sources.add(source.copyWith(url: decryptedUrl, isEncrypted: false));
            _logger.info('已解密配置源: [36m${source.name}[0m');
        } catch (e) {
          _logger.error('解密配置源 ${source.name} 失败: $e');
          sources.add(source); // 保留原始加密 URL
        }
      } else {
        sources.add(source);
      }
    }
    
    return sources;
  }
  
  /// 解析 YAML 配置字符串
  static ConfigSettings _parseYamlString(String yamlString) {
    try {
      // 解析 YAML
      final yamlDoc = loadYaml(yamlString);
      final configMap = _yamlToMap(yamlDoc);
      
      // 获取 xboard 配置节点
      final xboardConfig = configMap['xboard'] as Map<String, dynamic>? ?? {};
      
      // 提取配置参数
      final provider = xboardConfig['provider'] as String? ?? 'Flclash';
      final remoteConfigJson = xboardConfig['remote_config'] as Map<String, dynamic>? ?? {};
      final subscriptionJson = xboardConfig['subscription'] as Map<String, dynamic>? ?? {};
      final logJson = xboardConfig['log'] as Map<String, dynamic>? ?? {};
      
      // 构建配置对象
      return ConfigSettings(
        currentProvider: provider,
        remoteConfig: _parseRemoteConfig(remoteConfigJson),
        subscription: _parseSubscriptionSettings(subscriptionJson),
        log: _parseLogSettings(logJson),
      );
    } catch (e) {
      _logger.error('解析 YAML 配置失败', e);
      rethrow;
    }
  }
  
  /// 将 YAML 转换为 Map（或其他类型）
  static dynamic _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      yaml.forEach((key, value) {
        map[key.toString()] = _yamlToMap(value);
      });
      return map;
    } else if (yaml is YamlList) {
      return yaml.map((item) => _yamlToMap(item)).toList();
    } else {
      return yaml;
    }
  }
  
  /// 解析远程配置
  static RemoteConfigSettings _parseRemoteConfig(Map<String, dynamic> json) {
    final sourcesList = json['sources'] as List<dynamic>? ?? [];
    _logger.info('[ConfigLoader] 解析远程配置源: ${sourcesList.length} 个源');
    
    final sources = sourcesList
        .map((item) => _parseRemoteSource(item as Map<String, dynamic>))
        .toList();
    
    _logger.info('[ConfigLoader] 成功解析 ${sources.length} 个配置源');
    for (final source in sources) {
      _logger.info('[ConfigLoader] - ${source.name}: ${source.url}');
    }
    
    return RemoteConfigSettings(
      sources: sources,
      maxRetries: json['max_retries'] as int? ?? 3,
      timeout: Duration(seconds: json['timeout_seconds'] as int? ?? 10),
      retryDelay: Duration(seconds: json['retry_delay_seconds'] as int? ?? 2),
    );
  }
  
  /// 解析远程源配置
  static RemoteSourceConfig _parseRemoteSource(Map<String, dynamic> json) {
    final isEncrypted = json['encrypted'] as bool? ?? false;
    return RemoteSourceConfig(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      priority: json['priority'] as int? ?? 50,
      headers: (json['headers'] as Map<String, dynamic>?)?.cast<String, String>(),
      timeout: json['timeout_seconds'] != null 
          ? Duration(seconds: json['timeout_seconds'] as int)
          : null,
      encryptionKey: json['encryption_key'] as String?,
      isEncrypted: isEncrypted,
    );
  }
  
  /// 解析订阅设置
  static SubscriptionSettings _parseSubscriptionSettings(Map<String, dynamic> json) {
    return SubscriptionSettings(
      preferEncrypt: json['prefer_encrypt'] as bool? ?? false,
    );
  }
  
  /// 解析日志设置
  static LogSettings _parseLogSettings(Map<String, dynamic> json) {
    return LogSettings(
      enabled: json['enabled'] as bool? ?? true,
      level: json['level'] as String? ?? 'info',
      prefix: json['prefix'] as String? ?? '[XBoard]',
    );
  }
  
  /// 获取配置文件的其他配置项
  /// 
  /// 从 assets/config/xboard.config.yaml 加载扩展配置
  static Future<Map<String, dynamic>> loadExtendedConfig() async {
    try {
      final yamlString = await rootBundle.loadString(configPath);
      final yamlDoc = loadYaml(yamlString);
      final configMap = _yamlToMap(yamlDoc);
      
      return configMap['xboard'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      _logger.error('加载扩展配置失败', e);
      return {};
    }
  }
}

/// 配置辅助函数
extension ConfigFileLoaderHelper on ConfigFileLoader {
  /// 获取订阅设置
  static Future<SubscriptionSettings> getSubscriptionSettings() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      final subscriptionJson = config['subscription'] as Map<String, dynamic>? ?? {};
      return SubscriptionSettings(
        preferEncrypt: subscriptionJson['prefer_encrypt'] as bool? ?? false,
      );
    } catch (e) {
      return const SubscriptionSettings();
    }
  }
  
  /// 获取是否优先使用加密订阅
  static Future<bool> getPreferEncrypt() async {
    try {
      final settings = await getSubscriptionSettings();
      return settings.preferEncrypt;
    } catch (e) {
      return true;
    }
  }
  
  /// 获取是否启用订阅URL竞速（自动跟随加密选项）
  static Future<bool> getEnableRace() async {
    try {
      final settings = await getSubscriptionSettings();
      return settings.enableRace; // enableRace 是计算属性，等于 preferEncrypt
    } catch (e) {
      return true;
    }
  }
  
  /// 获取延迟测试配置
  static Future<String> getLatencyTestUrl() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      final latencyTest = config['latency_test'] as Map<String, dynamic>? ?? {};
      return latencyTest['test_url'] as String? ?? 'http://www.gstatic.com/generate_204';
    } catch (e) {
      return 'http://www.gstatic.com/generate_204';
    }
  }
  

  
  /// 获取 SDK 配置
  static Future<Map<String, dynamic>> getSdkConfig() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      return config['sdk'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }
  
  /// 获取应用配置
  static Future<Map<String, dynamic>> getAppConfig() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      return config['app'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }
  
  /// 获取安全配置
  static Future<Map<String, dynamic>> getSecurityConfig() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      return config['security'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }
  
  /// 获取解密密钥
  static Future<String> getDecryptKey() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      final subscription = config['subscription'] as Map<String, dynamic>? ?? {};
      return subscription['decrypt_key'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }
  
  /// 获取 User-Agent 配置
  static Future<Map<String, String>> getUserAgents() async {
    try {
      final security = await getSecurityConfig();
      final userAgents = security['user_agents'] as Map<String, dynamic>? ?? {};
      return userAgents.cast<String, String>();
    } catch (e) {
      return {};
    }
  }
  
  /// 获取证书配置
  static Future<Map<String, dynamic>> getCertificateConfig() async {
    // 硬编码证书配置，不再从配置文件读取
    // 禁用证书固定，因为测试环境没有证书文件
    return {
      'path': 'assets/cer/client-cert.crt',
      'enabled': false,
    };
  }
  
  /// 获取应用标题
  static Future<String> getAppTitle() async {
    try {
      final app = await getAppConfig();
      return app['title'] as String? ?? 'XBoard';
    } catch (e) {
      return 'XBoard';
    }
  }
  
  /// 获取应用网站地址
  static Future<String> getAppWebsite() async {
    try {
      final app = await getAppConfig();
      return app['website'] as String? ?? 'example.com';
    } catch (e) {
      return 'example.com';
    }
  }
  
  /// 获取混淆前缀字符串
  /// 
  /// 返回配置文件中的混淆前缀，如果未配置或配置为 null 则返回 null
  /// 用于 Caddy 反代等场景的响应反混淆
  /// SDK 会自动检测响应是否包含此前缀，有则反混淆，无则直接解析
  static Future<String?> getObfuscationPrefix() async {
    try {
      final security = await getSecurityConfig();
      final prefix = security['obfuscation_prefix'];
      
      // 如果配置为空字符串或 null，返回 null
      if (prefix == null || (prefix is String && prefix.isEmpty)) {
        return null;
      }
      
      return prefix as String;
    } catch (e) {
      _logger.warning('获取混淆前缀失败: $e');
      return null;
    }
  }
}

