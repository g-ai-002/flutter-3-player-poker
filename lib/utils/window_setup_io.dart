import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../services/log_service.dart';
import 'constants.dart';

/// 桌面窗口初始化：仅 Windows 生效，使用横向牌桌比例并限制最小尺寸。
Future<void> setupDesktopWindow() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
  try {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1180, 780),
      minimumSize: Size(760, 560),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppConstants.appName,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    LogService.warning('窗口管理器初始化失败: $e');
  }
}
