/// 敏感数据加密工具
///
/// 用于加密本地存储中的敏感信息（如订阅 URL、token 等）
/// 防止 shared_preferences.json 文件泄露敏感数据
library;

import 'dart:convert';
import 'dart:typed_data';

/// 敏感数据加密器
class SensitiveDataEncryptor {
  static const String _encryptionKey = 'FlClash_Local_Storage_2024_secure_key';
  static const String _encryptedPrefix = 'ENC:';

  /// XOR 加密/解密（对称操作）
  static Uint8List _xorCipher(Uint8List data, String key) {
    final keyBytes = utf8.encode(key);
    final keyLength = keyBytes.length;
    final result = Uint8List(data.length);

    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyBytes[i % keyLength];
    }

    return result;
  }

  /// 加密字符串
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    try {
      final plainBytes = utf8.encode(plainText);
      final encryptedBytes =
          _xorCipher(Uint8List.fromList(plainBytes), _encryptionKey);
      return '$_encryptedPrefix${base64.encode(encryptedBytes)}';
    } catch (e) {
      return plainText;
    }
  }

  /// 解密字符串
  static String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return encryptedText;
    try {
      if (!encryptedText.startsWith(_encryptedPrefix)) {
        // 没有标记，说明是旧的明文数据，直接返回
        return encryptedText;
      }

      final encoded = encryptedText.substring(_encryptedPrefix.length);
      final encryptedBytes = base64.decode(encoded);
      final decryptedBytes = _xorCipher(encryptedBytes, _encryptionKey);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      return encryptedText;
    }
  }

  /// 检查字符串是否已加密
  static bool isEncrypted(String text) {
    return text.startsWith(_encryptedPrefix);
  }

  /// 加密 URL（如果是有效的 HTTP/HTTPS URL）
  static String encryptUrl(String url) {
    if (url.isEmpty) return url;
    // 只加密 HTTP/HTTPS URL
    if (url.toLowerCase().startsWith('http://') ||
        url.toLowerCase().startsWith('https://')) {
      return encrypt(url);
    }
    return url;
  }

  /// 解密 URL
  static String decryptUrl(String url) {
    return decrypt(url);
  }
}
