import 'dart:io';

import 'package:fl_clash/common/common.dart';

class SingleInstanceLock {
  static SingleInstanceLock? _instance;
  RandomAccessFile? _accessFile;

  SingleInstanceLock._internal();

  factory SingleInstanceLock() {
    _instance ??= SingleInstanceLock._internal();
    return _instance!;
  }

  Future<bool> acquire() async {
    try {
      final lockFilePath = await appPath.lockFilePath;
      final lockFile = File(lockFilePath);
      await lockFile.create();
      _accessFile = await lockFile.open(mode: FileMode.write);
      await _accessFile?.lock();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 释放单实例锁（重启应用前必须先放掉，否则新进程会被判定为重复启动）
  Future<void> release() async {
    try {
      await _accessFile?.unlock();
      await _accessFile?.close();
    } catch (_) {
      // 忽略释放失败
    }
    _accessFile = null;
  }
}

final singleInstanceLock = SingleInstanceLock();
