import 'dart:io';

import 'package:flutter_3_player_poker/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('日志写入按天文件并可读取', () async {
    final dir = await Directory.systemTemp.createTemp('ddz_log_test');
    LogService.reset();
    await LogService.init(logRoot: () async => dir);
    LogService.info('测试日志消息');
    LogService.warning('警告消息');

    expect(LogService.logFilePath, contains('app_'));
    final file = File(LogService.logFilePath);
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('测试日志消息'));
    expect(content, contains('WARN'));

    final recent = LogService.getRecentLogs(10);
    expect(recent.any((line) => line.contains('测试日志消息')), isTrue);

    LogService.reset();
    await dir.delete(recursive: true);
  });
}
