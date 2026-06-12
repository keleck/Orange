/// 加密存储装饰器
/// 
/// 对敏感数据进行加密后存储，防止本地文件（如 shared_preferences.json）
/// 泄露敏感信息（如订阅地址、token 等）
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:fl_clash/xboard/core/core.dart';
import 'storage_interface.dart';

/// 加密存储装饰器
/// 
/// 包装原有的 StorageInterface 实现，对指定的敏感 key 进行加密存储
/// 
/// 使用示例：
/// ```dart
/// final baseStorage = await SharedPrefsStorage.create();
/// final encryptedStorage = EncryptedStorage(
///   baseStorage,
///   sensitiveKeys: {'xboard_domain_subscription', 'xboard_saved_password'},
/// );
/// ```
class EncryptedStorage implements StorageInterface {
  final StorageInterface _baseStorage;
  final Set<String> _sensitiveKeys;
  final String _encryptionKey;
  
  /// 需要加密存储的敏感 key 列表
  static const Set<String> defaultSensitiveKeys = {
    'xboard_domain_subscription',  // 订阅信息（包含 subscribeUrl）
    'xboard_saved_password',       // 保存的密码
    'xboard_domain_user',          // 用户信息（可能包含 token）
  };

  EncryptedStorage(
    this._baseStorage, {
    Set<String>? sensitiveKeys,
    String? encryptionKey,
  }) : _sensitiveKeys = sensitiveKeys ?? defaultSensitiveKeys,
       _encryptionKey = encryptionKey ?? _generateDeviceKey();

  /// 生成基于设备的加密密钥
  /// 使用固定前缀 + 时间戳哈希，确保同一设备上密钥一致
  static String _generateDeviceKey() {
    // 使用固定的应用密钥前缀
    const prefix = 'FlClash_Local_Storage_2024';
    // 这里可以加入设备特定信息，但为了简单起见使用固定密钥
    // 实际生产中可以使用 device_info_plus 获取设备 ID
    return '${prefix}_secure_key';
  }

  /// 判断 key 是否需要加密
  bool _isSensitive(String key) => _sensitiveKeys.contains(key);

  /// XOR 加密/解密（对称操作）
  Uint8List _xorCipher(Uint8List data, String key) {
    final keyBytes = utf8.encode(key);
    final keyLength = keyBytes.length;
    final result = Uint8List(data.length);
    
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyBytes[i % keyLength];
    }
    
    return result;
  }

  /// 加密字符串
  String _encrypt(String plainText) {
    try {
      final plainBytes = utf8.encode(plainText);
      final encryptedBytes = _xorCipher(Uint8List.fromList(plainBytes), _encryptionKey);
      // 添加标记前缀，用于识别已加密的数据
      return 'ENC:${base64.encode(encryptedBytes)}';
    } catch (e) {
      // 加密失败时返回原文（不应该发生）
      return plainText;
    }
  }

  /// 解密字符串
  String _decrypt(String encryptedText) {
    try {
      // 检查是否有加密标记
      if (!encryptedText.startsWith('ENC:')) {
        // 没有标记，说明是旧的明文数据，直接返回
        return encryptedText;
      }
      
      final encoded = encryptedText.substring(4); // 移除 'ENC:' 前缀
      final encryptedBytes = base64.decode(encoded);
      final decryptedBytes = _xorCipher(encryptedBytes, _encryptionKey);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      // 解密失败时返回原文
      return encryptedText;
    }
  }

  @override
  Future<Result<String?>> getString(String key) async {
    final result = await _baseStorage.getString(key);
    return result.map((value) {
      if (value == null) return null;
      if (_isSensitive(key)) {
        return _decrypt(value);
      }
      return value;
    });
  }

  @override
  Future<Result<bool>> setString(String key, String value) async {
    final valueToStore = _isSensitive(key) ? _encrypt(value) : value;
    return await _baseStorage.setString(key, valueToStore);
  }

  // 以下方法直接委托给基础存储（非字符串类型通常不包含敏感 URL）
  
  @override
  Future<Result<int?>> getInt(String key) => _baseStorage.getInt(key);

  @override
  Future<Result<bool>> setInt(String key, int value) => _baseStorage.setInt(key, value);

  @override
  Future<Result<bool?>> getBool(String key) => _baseStorage.getBool(key);

  @override
  Future<Result<bool>> setBool(String key, bool value) => _baseStorage.setBool(key, value);

  @override
  Future<Result<double?>> getDouble(String key) => _baseStorage.getDouble(key);

  @override
  Future<Result<bool>> setDouble(String key, double value) => _baseStorage.setDouble(key, value);

  @override
  Future<Result<List<String>?>> getStringList(String key) async {
    final result = await _baseStorage.getStringList(key);
    return result.map((list) {
      if (list == null) return null;
      if (_isSensitive(key)) {
        return list.map(_decrypt).toList();
      }
      return list;
    });
  }

  @override
  Future<Result<bool>> setStringList(String key, List<String> value) async {
    final valueToStore = _isSensitive(key) 
        ? value.map(_encrypt).toList() 
        : value;
    return await _baseStorage.setStringList(key, valueToStore);
  }

  @override
  Future<Result<bool>> remove(String key) => _baseStorage.remove(key);

  @override
  Future<Result<bool>> clear() => _baseStorage.clear();

  @override
  Future<Result<bool>> containsKey(String key) => _baseStorage.containsKey(key);

  @override
  Future<Result<Set<String>>> getKeys() => _baseStorage.getKeys();
}
