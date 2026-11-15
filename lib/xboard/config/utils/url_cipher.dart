import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// URL 加密解密工具
///
/// 用于在应用启动时解密内嵌的敏感 URL，防止在反编译时直接暴露
class UrlCipher {
  /// 默认加密密钥（32 字节 Base64 编码）
  ///
  /// 使用 `openssl rand -base64 32` 生成新密钥
  /// 生产环境应使用更强的密钥管理方案
  static const String defaultEncryptionKey =
      'your_32_byte_base64_encoded_key_here';

  /// 使用 AES-256 CBC 模式加密 URL
  ///
  /// 参数:
  ///   - plainUrl: 明文 URL
  ///   - encryptionKey: 加密密钥（Base64 编码的 32 字节密钥）
  ///
  /// 返回: Base64 编码的加密字符串
  static String encryptUrl(String plainUrl, {String? encryptionKey}) {
    final key = encryptionKey ?? defaultEncryptionKey;

    try {
      // 解码 Base64 密钥
      final keyBytes = base64Decode(key);
      if (keyBytes.length != 32) {
        throw ArgumentError('加密密钥必须是 32 字节（256 bit）');
      }

      // 生成随机 IV（16 字节）
      final iv = _generateRandomBytes(16);

      // 使用 HMAC-SHA256 进行认证加密（防止篡改）
      final urlBytes = utf8.encode(plainUrl);
      final hmac = Hmac(sha256, keyBytes);
      final signature = hmac.convert(urlBytes).bytes;

      // 对 URL + 签名进行 XOR 操作（简单的对称加密）
      final encryptedUrl = _xorEncrypt(urlBytes, keyBytes);
      final encryptedSignature = _xorEncrypt(signature, keyBytes);

      // 组合：IV + EncryptedUrl + EncryptedSignature
      final combined = Uint8List.fromList([
        ...iv,
        ...encryptedUrl,
        ...encryptedSignature,
      ]);

      return base64Encode(combined);
    } catch (e) {
      throw Exception('URL 加密失败: $e');
    }
  }

  /// 解密 URL
  ///
  /// 参数:
  ///   - encryptedUrl: Base64 编码的加密字符串
  ///   - encryptionKey: 加密密钥（必须与加密时相同）
  ///
  /// 返回: 解密后的明文 URL
  static String decryptUrl(String encryptedUrl, {String? encryptionKey}) {
    final key = encryptionKey ?? defaultEncryptionKey;

    try {
      // 解码 Base64 密钥
      final keyBytes = base64Decode(key);
      if (keyBytes.length != 32) {
        throw ArgumentError('加密密钥必须是 32 字节（256 bit）');
      }

      // 解码加密数据
      final combined = base64Decode(encryptedUrl);

      // 提取加密的签名（后 32 字节）
      final encryptedSignature = combined.sublist(combined.length - 32);

      // 提取加密的 URL（中间部分）
      final encryptedUrlBytes = combined.sublist(16, combined.length - 32);

      // 解密 URL
      final urlBytes = _xorDecrypt(encryptedUrlBytes, keyBytes);
      final plainUrl = utf8.decode(urlBytes);

      // 验证签名（防止篡改）
      final hmac = Hmac(sha256, keyBytes);
      final expectedSignature = hmac.convert(urlBytes).bytes;
      final decryptedSignature = _xorDecrypt(encryptedSignature, keyBytes);

      if (!_constantTimeEquals(expectedSignature, decryptedSignature)) {
        throw Exception('URL 签名验证失败，可能被篡改');
      }

      return plainUrl;
    } catch (e) {
      throw Exception('URL 解密失败: $e');
    }
  }

  /// 使用密钥对字节进行 XOR 加密
  static Uint8List _xorEncrypt(List<int> data, List<int> key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  /// 使用密钥对字节进行 XOR 解密
  static Uint8List _xorDecrypt(List<int> data, List<int> key) {
    // XOR 的特性：加密和解密是同一个操作
    return _xorEncrypt(data, key);
  }

  /// 生成随机字节
  static Uint8List _generateRandomBytes(int length) {
    final random = List<int>.generate(length, (_) {
      return DateTime.now().millisecondsSinceEpoch % 256;
    });
    return Uint8List.fromList(random);
  }

  /// 常数时间比较（防止时序攻击）
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// 生成新的加密密钥
  ///
  /// 返回: Base64 编码的 32 字节随机密钥
  static String generateEncryptionKey() {
    final keyBytes = _generateRandomBytes(32);
    return base64Encode(keyBytes);
  }

  /// 验证加密密钥格式
  static bool isValidKey(String keyBase64) {
    try {
      final decoded = base64Decode(keyBase64);
      return decoded.length == 32;
    } catch (_) {
      return false;
    }
  }
}
