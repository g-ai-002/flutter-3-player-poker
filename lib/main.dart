import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'providers/game_provider.dart';
import 'providers/settings_provider.dart';
import 'services/audio_service.dart';
import 'services/hand_history_service.dart';
import 'services/log_service.dart';
import 'services/logging_init.dart';
import 'services/stats_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'utils/system_ui.dart';
import 'utils/window_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupDesktopWindow();

  final storage = await StorageService.instance;
  await initLogging();
  await StatsService.instance.load();
  await HandHistoryService.instance.load();
  LogService.info('应用启动: ${AppConstants.appName} v${AppConstants.version}');

  FlutterError.onError = (details) {
    LogService.error(
      'Flutter 异常: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.error('未捕获的异步异常', error, stack);
    return false;
  };

  runApp(PokerApp(storage: storage));
  // 桌面与移动端启动即预热音频；Web 端等首次点击后再初始化，避免自动播放策略拦截。
  if (!kIsWeb) unawaited(AudioService.instance.initialize());
}

class PokerApp extends StatelessWidget {
  const PokerApp({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    final fontFamily =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
        ? 'Microsoft YaHei UI'
        : null;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(
          create: (context) =>
              GameProvider(settings: context.read<SettingsProvider>()),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(fontFamily: fontFamily),
            darkTheme: buildDarkTheme(fontFamily: fontFamily),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            builder: (context, child) =>
                SystemUiOverlay(child: child ?? const SizedBox.shrink()),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
