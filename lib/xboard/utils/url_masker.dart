/// URL掩码工具
/// 
/// 用于在日志中隐藏敏感信息（如token、密钥等）
class UrlMasker {
  /// 掩码URL中的敏感信息
  /// 
  /// 完全隐藏URL，不显示任何信息
  static String mask(String url) {
    return '***';
  }
}
