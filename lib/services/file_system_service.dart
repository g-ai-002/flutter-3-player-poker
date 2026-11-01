/// 文件系统服务：按平台选择实现——IO 平台读写应用目录，Web 平台返回空路径。
library;

export 'file_system_service_io.dart'
    if (dart.library.js_interop) 'file_system_service_web.dart';
