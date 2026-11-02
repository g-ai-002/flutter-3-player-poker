import 'dart:io';

/// `flutter test` 会设置该环境变量；单元测试中禁用音频插件，避免原生通道缺失。
bool get isFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');
