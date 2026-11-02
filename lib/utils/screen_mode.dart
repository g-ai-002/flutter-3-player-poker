import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 手机进入牌桌时切到全屏横屏，退出时恢复系统方向与状态栏。
///
/// 只在 Android 手机上生效：折叠屏与平板保留系统当前的旋转与分屏体验。
Future<void> enterGameFullscreen() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
    if (shortest >= 600) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (error) {
    debugPrint('进入全屏横屏失败: $error');
  }
}

Future<void> exitGameFullscreen() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (error) {
    debugPrint('恢复屏幕方向失败: $error');
  }
}
