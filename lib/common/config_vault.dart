import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:fl_clash/common/path.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart' as pc;

/// 订阅配置的加密存储。
///
/// 设计目标：
/// - 配置文件不以明文落盘，避免别人直接打开看到订阅内容
/// - 文件名固定，换订阅只覆盖同一个文件，不会堆出一堆 yaml
///
/// 加密方案：PBKDF2-HMAC-SHA256 派生密钥 + AES-256-CBC。
/// 每次保存生成新的随机 salt 与 IV，写在文件头部：
///
///   [ salt(16) | iv(16) | ciphertext ]
///
/// 说明：口令内置在客户端，这能挡住「直接查看/拷走文件」，但挡不住
/// 针对二进制的逆向分析。
class ConfigVault {
  ConfigVault._();

  /// 固定文件名，所有订阅共用这一份
  static const String fileName = 'config.bin';

  /// 派生用的口令
  static const String _passphrase = 'mxycloud-config-vault-2026-11-11';

  static const int _saltLength = 16;
  static const int _ivLength = 16;
  static const int _keyLength = 32; // AES-256
  static const int _iterations = 10000;

  /// 同一份 salt 只派生一次，避免每次下发配置都跑一遍 PBKDF2
  static final Map<String, Uint8List> _keyCache = {};

  static Future<File> _resolveFile() async {
    final dir = await appPath.profilesPath;
    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(p.join(dir, fileName));
  }

  static Uint8List _deriveKey(Uint8List salt) {
    final cacheKey = base64.encode(salt);
    final cached = _keyCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, _iterations, _keyLength));
    final key = derivator.process(Uint8List.fromList(utf8.encode(_passphrase)));
    _keyCache[cacheKey] = key;
    return key;
  }

  static Future<bool> exists() async {
    try {
      final file = await _resolveFile();
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// 加密写入
  static Future<void> save(List<int> plain) async {
    final salt = IV.fromSecureRandom(_saltLength).bytes;
    final iv = IV.fromSecureRandom(_ivLength);
    final encrypter = Encrypter(AES(Key(_deriveKey(salt)), mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plain, iv: iv);
    final payload = Uint8List.fromList([...salt, ...iv.bytes, ...encrypted.bytes]);
    final file = await _resolveFile();
    await file.writeAsBytes(payload, flush: true);
  }

  /// 读取并解密，失败返回 null（当作没有配置）
  static Future<Uint8List?> load() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsBytes();
      final headerLength = _saltLength + _ivLength;
      if (raw.length <= headerLength) {
        return null;
      }
      final salt = Uint8List.fromList(raw.sublist(0, _saltLength));
      final iv = IV(
        Uint8List.fromList(raw.sublist(_saltLength, headerLength)),
      );
      final cipher = Encrypted(Uint8List.fromList(raw.sublist(headerLength)));
      final encrypter = Encrypter(AES(Key(_deriveKey(salt)), mode: AESMode.cbc));
      final plain = encrypter.decryptBytes(cipher, iv: iv);
      if (plain.isEmpty) {
        return null;
      }
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> lastModified() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }
      return await file.lastModified();
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 删不掉不影响主流程
    }
  }
}
