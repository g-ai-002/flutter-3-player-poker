import 'dart:io';

import 'package:flutter_3_player_poker/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec 版本号与 AppConstants.version 保持一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(version, isNotNull, reason: 'pubspec.yaml 需要 SemVer 版本号');
    expect(version!.group(1), AppConstants.version);
    final build = version.group(2);
    if (build != null) {
      expect(int.parse(build), greaterThan(0));
    }
  });

  test('pubspec 依赖全部使用固定版本号', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final block = RegExp(
      r'^dependencies:\n((?:[ \t].*\n|\n)+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(block, isNotNull, reason: 'pubspec.yaml 需要 dependencies 段');
    final pins = <String, String>{};
    for (final line in block!.group(1)!.split('\n')) {
      final match = RegExp(r'^  ([a-z0-9_]+):\s*(\S.*)$').firstMatch(line);
      if (match == null) continue;
      pins[match.group(1)!] = match.group(2)!.trim();
    }

    final thirdParty = pins.entries.where((e) => e.value != 'sdk: flutter');
    expect(thirdParty, isNotEmpty, reason: '需要解析出第三方依赖');
    for (final entry in thirdParty) {
      expect(
        RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?$').hasMatch(entry.value),
        isTrue,
        reason: '${entry.key} 必须写死版本号, 当前为 ${entry.value}',
      );
    }
  });
}
