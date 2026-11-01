/// Web 平台文件系统服务：浏览器没有可写的本地目录。
///
/// 保持与 IO 实现相同的公开 API，调用方按空路径处理即可。
class FileSystemService {
  FileSystemService._(this.appDirName);

  static final FileSystemService instance = FileSystemService._('FlutterDdz');

  /// 应用数据目录名（Web 端仅用于展示）。
  final String appDirName;

  Future<String> getLogRootPath() async => '';

  /// 浏览器无法打开系统文件管理器。
  Future<bool> openDirectory(String path) async => false;
}
