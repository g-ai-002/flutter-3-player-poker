import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/formatters.dart';

/// 日志服务：内存环形缓冲 + 按天文件落盘。
///
/// - 初始化前产生的日志先进入早期缓冲，初始化后自动补写文件；
/// - 日志目录不可用时（单测/异常环境）降级为仅内存模式，绝不阻断启动；
/// - 跨天自动切换日志文件，单文件超过大小上限自动轮转，过期文件自动清理；
/// - 日志根目录由 [init] 的 `logRoot` 注入，本类不感知各项目的目录约定。
class LogService {
  static LogService? _instance;
  static final List<String> _earlyBuffer = [];
  final List<String> _buffer = [];
  Directory? _logDir;
  File? _logFile;
  DateTime? _logDate;
  bool _initialized = false;
  DateTime Function() _now = DateTime.now;

  static const int _maxBufferLines = 2000;
  static const int _maxEarlyLines = 500;
  static const int _maxFileSize = 5 * 1024 * 1024;
  static const int _maxRetentionDays = 7;

  LogService._();

  static Future<void> init({
    Future<Directory> Function()? logRoot,
    DateTime Function()? clock,
  }) async {
    _instance ??= LogService._();
    await _instance!._init(logRoot, clock);
  }

  /// 仅用于测试：重置单例与早期缓冲
  static void reset() {
    _instance = null;
    _earlyBuffer.clear();
  }

  Future<void> _init(
    Future<Directory> Function()? logRoot,
    DateTime Function()? clock,
  ) async {
    if (_initialized) return;
    if (clock != null) _now = clock;
    if (logRoot != null) {
      try {
        _logDir = await logRoot();
      } catch (e) {
        debugPrint('[LogService] 日志目录不可用，降级为内存日志: $e');
      }
    }
    _logFile = _openTodayFile();
    _initialized = true;
    if (_logFile != null) {
      _logDate = _now();
      _cleanOldLogs();
    }
    // 补写初始化前的早期日志（启动步骤失败等），并保留在内存缓冲中
    if (_earlyBuffer.isNotEmpty) {
      for (final line in _earlyBuffer) {
        _buffer.add(line);
        _appendLine(line);
      }
      _earlyBuffer.clear();
    }
    _write(
      'INFO',
      '==== LogService 已初始化, 日志文件: ${_logFile?.path ?? '内存模式'} ====',
    );
  }

  /// 当前日志文件路径（内存模式或未初始化时为空串）
  static String get logFilePath => _instance?._logFile?.path ?? '';

  static void info(String message) => _log('INFO', message);

  static void warning(String message) => _log('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    final msg = error != null ? '$message | $error' : message;
    _log('ERROR', msg);
    if (stack != null) {
      _log('ERROR', stack.toString());
    }
  }

  static void _log(String level, String message) {
    final inst = _instance;
    if (inst == null || !inst._initialized) {
      final line = formatLogLine(
        inst?._now() ?? DateTime.now(),
        level,
        message,
      );
      _earlyBuffer.add(line);
      if (_earlyBuffer.length > _maxEarlyLines) {
        _earlyBuffer.removeAt(0);
      }
      return;
    }
    inst._write(level, message);
  }

  void _write(String level, String message) {
    final line = formatLogLine(_now(), level, message);
    _buffer.add(line);
    if (_buffer.length > _maxBufferLines) {
      _buffer.removeAt(0);
    }
    _appendLine(line);
  }

  void _appendLine(String line) {
    try {
      _refreshLogFile();
      _logFile?.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// 写文件前检查：跨天切换新文件、单文件超限轮转。失败静默（内存缓冲仍保留日志）。
  void _refreshLogFile() {
    if (_logDir == null) return;
    final now = _now();
    final current = _logDate;
    final needSwitch =
        current == null ||
        current.year != now.year ||
        current.month != now.month ||
        current.day != now.day;
    if (needSwitch) {
      final file = _openTodayFile();
      if (file != null) {
        _logFile = file;
        _logDate = now;
        _cleanOldLogs();
      }
      return;
    }
    _rotateIfNeeded();
  }

  File? _openTodayFile() {
    final dir = _logDir;
    if (dir == null) return null;
    try {
      final now = _now();
      final dateStr = formatDateKey(now);
      final file = File('${dir.path}${Platform.pathSeparator}app_$dateStr.log');
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      return file;
    } catch (_) {
      return null;
    }
  }

  /// 单文件超过大小上限时轮转为 `app_YYYYMMDD_N.log` 备份
  void _rotateIfNeeded() {
    final file = _logFile;
    if (file == null) return;
    try {
      if (!file.existsSync() || file.lengthSync() < _maxFileSize) return;
      final originalPath = file.path;
      final parent = file.parent;
      final baseName = file.uri.pathSegments.last.replaceAll('.log', '');
      var index = 1;
      File backup;
      do {
        backup = File(
          '${parent.path}${Platform.pathSeparator}${baseName}_$index.log',
        );
        index++;
      } while (backup.existsSync());
      file.renameSync(backup.path);
      final fresh = File(originalPath);
      if (!fresh.existsSync()) {
        fresh.createSync();
      }
      _logFile = fresh;
    } catch (_) {}
  }

  /// 清理超过保留期的日志文件（含轮转备份），初始化与跨天切换时各执行一次
  void _cleanOldLogs() {
    final dir = _logDir;
    if (dir == null) return;
    try {
      final cutoff = _now().subtract(const Duration(days: _maxRetentionDays));
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('app_') || !name.endsWith('.log')) continue;
        try {
          if (entity.statSync().modified.isBefore(cutoff)) {
            entity.deleteSync();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// 最近日志（内存缓冲，含尚未落盘的早期日志）
  static List<String> getRecentLogs([int lines = 200]) {
    final inst = _instance;
    final all = <String>[..._earlyBuffer, if (inst != null) ...inst._buffer];
    if (all.length <= lines) {
      return all;
    }
    return all.sublist(all.length - lines);
  }
}
