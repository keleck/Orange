import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/common/sensitive_data_encryptor.dart';
import 'package:path/path.dart' as p;

/// 订阅配置的加密存储。
///
/// 设计目标：
/// - 配置文件不以明文落盘，避免别人直接打开看到订阅内容
/// - 文件名固定，换订阅只覆盖同一个文件，不会堆出一堆 yaml
///
/// 加密复用项目已有的 [SensitiveDataEncryptor]（与订阅 URL、token 的
/// 本地存储保持同一套方案）。它挡得住「直接打开文件查看」这类场景，
/// 但不是对抗逆向的强加密。
class ConfigVault {
  ConfigVault._();

  /// 固定文件名，所有订阅共用这一份
  static const String fileName = 'config.bin';

  static Future<File> _resolveFile() async {
    final dir = await appPath.profilesPath;
    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(p.join(dir, fileName));
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
    final text = utf8.decode(plain);
    final encrypted = SensitiveDataEncryptor.encrypt(text);
    final file = await _resolveFile();
    await file.writeAsString(encrypted, flush: true);
  }

  /// 读取并解密，失败返回 null（当作没有配置）
  static Future<Uint8List?> load() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }
      final encrypted = await file.readAsString();
      if (encrypted.isEmpty) {
        return null;
      }
      final text = SensitiveDataEncryptor.decrypt(encrypted);
      if (text.isEmpty) {
        return null;
      }
      return Uint8List.fromList(utf8.encode(text));
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
      return file.lastModified();
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
