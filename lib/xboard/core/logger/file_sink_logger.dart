import 'dart:async';
import 'dart:io';

import 'logger_interface.dart';

/// 同时写文件和标准输出的日志实现。
///
/// 桌面端从图标启动时 stdout 没有去处，`FileLogger` 实际上只打了控制台，
/// 出问题时无从排查。这里额外落一份到磁盘，用户可以直接把文件发过来。
class FileSinkLogger implements LoggerInterface {
  FileSinkLogger(this.logFile, {this.minLevel = LogLevel.info});

  final File logFile;

  @override
  LogLevel minLevel;

  static const String _prefix = '[XBoard]';

  final List<String> _buffer = [];
  Timer? _flushTimer;

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (minLevel.index <= LogLevel.debug.index) {
      _write('DEBUG', message, error, stackTrace);
    }
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (minLevel.index <= LogLevel.info.index) {
      _write('INFO', message, error, stackTrace);
    }
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (minLevel.index <= LogLevel.warning.index) {
      _write('WARN', message, error, stackTrace);
    }
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (minLevel.index <= LogLevel.error.index) {
      _write('ERROR', message, error, stackTrace);
    }
  }

  void _write(String level, String message, Object? error, StackTrace? stack) {
    final now = DateTime.now();
    final timestamp = '${now.year}-${_two(now.month)}-${_two(now.day)} '
        '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
    final buffer = StringBuffer('$timestamp [$level] $message');
    if (error != null) {
      buffer.write(' | error: $error');
    }
    if (stack != null) {
      buffer.write('\n$stack');
    }
    final text = buffer.toString();
    // ignore: avoid_print
    print('$_prefix$text');
    _buffer.add(text);
    // 攒一小批再写，避免高频日志拖慢主线程。
    _flushTimer ??= Timer(const Duration(seconds: 2), () {
      _flushTimer = null;
      flush();
    });
  }

  Future<void> flush() async {
    if (_buffer.isEmpty) {
      return;
    }
    final text = '${_buffer.join('\n')}\n';
    _buffer.clear();
    try {
      await logFile.parent.create(recursive: true);
      await logFile.writeAsString(text, mode: FileMode.append);
    } catch (_) {
      // 日志写不进去不应该影响主流程
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
