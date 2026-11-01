import 'package:flutter/foundation.dart';

import '../utils/formatters.dart';

/// Web 平台日志：只保留内存环形缓冲，不落盘。
///
/// 与 IO 实现保持相同的静态 API，调用方无需区分平台。
class LogService {
  LogService._();

  static final List<String> _buffer = [];
  static bool _initialized = false;

  static const int _maxBufferLines = 2000;

  /// Web 端没有可写目录，[logRoot] 参数仅为兼容调用方签名。
  static Future<void> init({
    Future<Object?> Function()? logRoot,
    DateTime Function()? clock,
  }) async {
    _initialized = true;
    _write('INFO', '==== LogService 已初始化, Web 内存模式 ====');
  }

  /// 仅用于测试：重置内存缓冲
  static void reset() {
    _buffer.clear();
    _initialized = false;
  }

  /// Web 端没有日志文件
  static String get logFilePath => '';

  static void info(String message) => _write('INFO', message);

  static void warning(String message) => _write('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    final msg = error != null ? '$message | $error' : message;
    _write('ERROR', msg);
    if (stack != null) {
      _write('ERROR', stack.toString());
    }
  }

  static void _write(String level, String message) {
    if (!_initialized) {
      // 与 IO 实现一致：初始化前的日志也保留在内存缓冲里。
      debugPrint('[LogService] $level $message');
    }
    _buffer.add(formatLogLine(DateTime.now(), level, message));
    if (_buffer.length > _maxBufferLines) {
      _buffer.removeAt(0);
    }
  }

  static List<String> getRecentLogs([int lines = 200]) {
    if (_buffer.length <= lines) {
      return List.unmodifiable(_buffer);
    }
    return _buffer.sublist(_buffer.length - lines);
  }
}
