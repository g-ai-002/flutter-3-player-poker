import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3_player_poker/utils/system_ui.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('启动与回到前台都会重新请求沉浸式全屏', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method.startsWith('SystemChrome.')) calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    bool immersive() => calls.any(
      (call) =>
          call.method == 'SystemChrome.setEnabledSystemUIMode' &&
          call.arguments == 'SystemUiMode.immersiveSticky',
    );

    await keepImmersiveFullscreen();
    expect(immersive(), isTrue, reason: '启动首页即全屏沉浸');

    keepFullscreenOnResume();
    calls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(immersive(), isTrue, reason: '从后台切回后系统栏不应常驻');
  });
}
