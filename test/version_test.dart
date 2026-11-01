import 'dart:io';

import 'package:flutter_3_player_poker/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec 版本号与 AppConstants.version 保持一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(version, isNotNull, reason: 'pubspec.yaml 需要 SemVer 版本与构建号');
    expect(version!.group(1), AppConstants.version);
    expect(int.parse(version.group(2)!), greaterThan(0));
  });
}
