import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3_player_poker/utils/system_ui.dart';

void main() {
  test('浅色底色配深色状态栏与导航栏图标', () {
    final style = systemOverlayStyleFor(const Color(0xFFF9F5EA));
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarColor, Colors.transparent);
  });

  test('深色底色配浅色状态栏与导航栏图标', () {
    final style = systemOverlayStyleFor(const Color(0xFF0A2318));
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });
}
