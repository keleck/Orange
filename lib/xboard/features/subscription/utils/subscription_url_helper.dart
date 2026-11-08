/// 订阅URL辅助工具
/// 
/// 用于解析和处理订阅URL，提取token等信息
class SubscriptionUrlHelper {
  static bool _initialized = false;

  /// 初始化URL辅助工具
  /// 
  /// 执行必要的初始化操作
  static void initialize() {
    if (_initialized) return;
    _initialized = true;
  }

  /// 从订阅URL中提取token
  /// 
  /// 支持多种URL格式：
  /// - https://domain.com/api/v1/client/subscribe?token=xxx
  /// - https://domain.com/api/v2/subscription-encrypt/xxx
  /// - https://domain.com/subscription/xxx
  /// - domain.com/api/v1/client/subscribe?token=xxx (自动补充协议)
  static String? extractTokenFromUrl(String url) {
    try {
      // 确保URL有协议前缀
      final normalizedUrl = _ensureProtocol(url);
      final uri = Uri.parse(normalizedUrl);
      
      // 方式1: 查询参数中的token
      if (uri.queryParameters.containsKey('token')) {
        return uri.queryParameters['token'];
      }
      
      // 方式2: 路径中的最后一段作为token
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        // 验证是否像token（一般是32位或更长的十六进制字符串）
        if (lastSegment.length >= 16 && RegExp(r'^[a-f0-9]+$').hasMatch(lastSegment)) {
          return lastSegment;
        }
      }
      
      return null;
    } catch (e) {
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

  /// 检查URL是否为加密订阅URL
  /// 
  /// 通过路径中是否包含 encrypt 关键字判断
  static bool isEncryptedSubscriptionUrl(String url) {
    try {
      final normalizedUrl = _ensureProtocol(url);
      final uri = Uri.parse(normalizedUrl);
      final path = uri.path.toLowerCase();
      
      return path.contains('encrypt');
    } catch (e) {
      return false;
    }
  }

  /// 判断URL是否需要使用加密订阅服务
  /// 
  /// 综合判断URL特征和配置信息
  static bool shouldUseEncryptedService(String url) {
    // 1. 检查URL是否为加密端点
    if (isEncryptedSubscriptionUrl(url)) {
      return true;
    }
    
    // 2. 检查是否能提取到token
    final token = extractTokenFromUrl(url);
    if (token != null && token.length >= 16) {
      return true;
    }
    
    return false;
  }
}