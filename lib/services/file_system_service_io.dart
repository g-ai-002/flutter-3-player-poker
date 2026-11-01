import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// 文件系统服务：解析用户目录与日志目录、打开系统文件管理器。
class FileSystemService {
  FileSystemService._(this.appDirName);

  static final FileSystemService instance = FileSystemService._('FlutterDdz');

  /// 应用数据目录名（位于 Documents 或应用外部存储下）
  final String appDirName;

  Directory? _logRoot;

  Future<Directory> _baseDir() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      return ext ?? await getApplicationDocumentsDirectory();
    }
    return getApplicationDocumentsDirectory();
  }

  /// 日志根目录：`<Documents 或 external>/<appDirName>/logs`
  Future<Directory> getLogRoot() async {
    if (_logRoot != null) return _logRoot!;
    final base = await _baseDir();
    final logDir = Directory(
      '${base.path}${Platform.pathSeparator}$appDirName'
      '${Platform.pathSeparator}logs',
    );
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _logRoot = logDir;
    return logDir;
  }

  /// 日志根目录路径（Web 端为空串，调用方无需感知 Directory 类型）。
  Future<String> getLogRootPath() async => (await getLogRoot()).path;

  /// 打开系统文件管理器定位到目录（桌面端），失败返回 false
  Future<bool> openDirectory(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
        return true;
      }
    } catch (e, stack) {
      LogService.error('打开目录失败: $path', e, stack);
    }
    return false;
  }
}
