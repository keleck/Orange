import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import 'lock.dart';
import 'path.dart';

/// 应用缓存清理。
///
/// 只清理可再生的缓存，**不动**登录状态（shared_preferences）、订阅配置（profiles）、
/// 自定义规则与内核文件，所以清理完不需要重新登录。
///
/// 清理项：
/// - Flutter 图片缓存（内存）
/// - 内核缓存 `cache.db`（fake-ip / DNS 结果，重启内核后自动重建）
/// - 数据目录下的 `cache` / `image_cache` / `logs` 目录
class AppCacheService {
  AppCacheService._();

  /// 数据目录下可再生的缓存目录
  static const List<String> _cacheDirNames = ['cache', 'image_cache', 'logs'];

  /// 执行清理，返回被删除的文件/目录数量
  static Future<int> clear() async {
    // 1. 图片缓存（内存）
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    var removed = 0;
    final home = await appPath.homeDirPath;

    // 2. 内核缓存：删掉后由内核在下次启动时重建
    removed += await _deleteEntity(p.join(home, 'cache.db'));

    // 3. 缓存目录
    for (final name in _cacheDirNames) {
      removed += await _clearDirectory(p.join(home, name));
    }

    return removed;
  }

  /// 重启应用。
  ///
  /// 桌面端会拉起新进程并退出当前进程；Android 不支持自重启，返回 false，
  /// 由调用方提示用户手动重启。
  static Future<bool> restart() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return false;
    }
    try {
      // 必须先释放单实例锁，否则新进程会被判定为重复启动直接退出
      await singleInstanceLock.release();
      await Process.start(
        Platform.resolvedExecutable,
        const [],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } catch (_) {
      return false;
    }
  }

  static Future<int> _clearDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return 0;
    }
    var count = 0;
    await for (final entity in dir.list(followLinks: false)) {
      count += await _deleteEntity(entity.path);
    }
    return count;
  }

  static Future<int> _deleteEntity(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return 0;
      }
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete();
      }
      return 1;
    } catch (_) {
      // 单个文件被占用就跳过，不阻塞整体清理
      return 0;
    }
  }
}
