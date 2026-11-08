import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 牌桌网格的设计宽高比：三家出牌区横向排开，横向空间直接决定牌面大小。
const double tableGridAspect = 2.2;

/// 竖屏 / 横屏下被顶栏、提示带、操作条与手牌占掉的固定高度（与 GameLayout 一致）。
///
/// 竖屏提示只能叠在网格上方，四条槽位共 92；横屏提示分列网格左右，顶部只留胶囊。
const double _portraitChrome = 40 + 92 + 40 + 118;
const double _landscapeChrome = 40 + 28 + 40 + 86;

/// 牌桌网格在某个视口里能放到的宽度：扣除固定占位后按设计比例取 min。
///
/// 纵向多出来的空间会变成留白，不会转成牌面宽度，因此这里比的是网格缩放而不是面积。
double tableGridWidth(Size viewport, {required double chrome}) {
  final width = viewport.width - 16;
  final height = viewport.height - chrome;
  if (width <= 0 || height <= 0) return 0;
  return math.min(width, height * tableGridAspect);
}

/// 窄屏是否更适合横屏：只有横屏能把网格放得明显更大才旋转，否则保持竖屏。
///
/// 长屏手机（如 360×780、390×844）横屏能拿到更宽的牌桌网格；接近正方形的矮屏
/// 手机（如 320×568）横屏后剩余高度不足，反而更挤，这里会判定保持竖屏。
bool prefersLandscape(Size viewport) {
  final shortSide = math.min(viewport.width, viewport.height);
  final longSide = math.max(viewport.width, viewport.height);
  final portrait = Size(shortSide, longSide);
  final landscape = Size(longSide, shortSide);
  return tableGridWidth(landscape, chrome: _landscapeChrome) >
      tableGridWidth(portrait, chrome: _portraitChrome) * 1.04;
}

/// 进入牌桌时要锁定的方向；屏幕够宽的平板 / 折叠屏返回 null，保留系统当前方向。
bool? tableOrientationLock(Size viewport) {
  if (viewport.shortestSide >= 600) return null;
  return prefersLandscape(viewport);
}

/// 手机进入牌桌时按网格比例决定横屏还是竖屏，退出时恢复系统方向与状态栏。
///
/// 只在 Android 手机上生效：折叠屏与平板屏幕够宽，保留系统当前的旋转与分屏体验。
Future<void> enterGameFullscreen() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    final landscape = tableOrientationLock(size);
    if (landscape == null) return;
    debugPrint('牌桌屏幕方向: ${landscape ? '横屏' : '竖屏'} ($size)');
    await SystemChrome.setPreferredOrientations(
      landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (error) {
    debugPrint('进入全屏失败: $error');
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
