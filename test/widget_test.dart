import 'package:flutter/material.dart';
import 'package:flutter_3_player_poker/pages/game_page.dart';
import 'package:flutter_3_player_poker/pages/home_page.dart';
import 'package:flutter_3_player_poker/pages/settings_page.dart';
import 'package:flutter_3_player_poker/pages/stats_page.dart';
import 'package:flutter_3_player_poker/providers/game_provider.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/stats_service.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_3_player_poker/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> makeSettings() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SettingsProvider(StorageService.test(prefs));
}

Widget wrapApp(Widget home, {SettingsProvider? settings, GameProvider? game}) {
  final provider = settings ?? SettingsProvider(StorageService.test());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      if (game != null) ChangeNotifierProvider.value(value: game),
    ],
    child: MaterialApp(theme: buildLightTheme(), home: home),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StatsService.instance.resetForTest();
  });

  testWidgets('主页展示入口与生涯概览', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    await tester.pumpWidget(
      wrapApp(const HomePage(), settings: settings, game: game),
    );
    await tester.pump();

    expect(find.text('斗地主'), findsOneWidget);
    expect(find.text('开始对局'), findsOneWidget);
    expect(find.text('玩法说明'), findsOneWidget);
    expect(find.text('数据统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('胜率'), findsOneWidget);
  });

  testWidgets('主页可进入玩法说明', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    await tester.pumpWidget(
      wrapApp(const HomePage(), settings: settings, game: game),
    );
    await tester.tap(find.text('玩法说明'));
    await tester.pumpAndSettle();

    expect(find.text('三人斗地主'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('王炸'), 250);
    expect(find.text('王炸'), findsOneWidget);
  });

  testWidgets('牌桌展示手牌与操作按钮，提示可选中牌', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    game.newGame();
    game.engine.currentPlayer = 0;
    game.bid(true);

    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('斗地主'), findsOneWidget);
    expect(find.text('出牌'), findsOneWidget);
    expect(find.text('提示'), findsOneWidget);
    expect(find.text('不出'), findsOneWidget);
    expect(game.humanHand.length, 20);
    expect(
      find.byKey(ValueKey('hand-card-${game.humanHand.first.id}')),
      findsOneWidget,
    );

    game.hint();
    await tester.pump();
    expect(game.selectedIds, isNotEmpty);

    await tester.tap(find.text('出牌'));
    await tester.pump(const Duration(milliseconds: 20));
    expect(game.humanHand.length, lessThan(20));
  });

  testWidgets('牌桌在手机竖屏与横屏均无溢出', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);
    game.newGame();
    game.engine.currentPlayer = 0;
    game.bid(true);

    for (final size in [const Size(360, 780), const Size(780, 360)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        wrapApp(const GamePage(), settings: settings, game: game),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('出牌'), findsOneWidget);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('设置页展示主题与 AI 速度选项', (tester) async {
    final settings = await makeSettings();
    await tester.pumpWidget(wrapApp(const SettingsPage(), settings: settings));
    await tester.pump();

    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('AI 思考速度'), findsOneWidget);
    expect(find.text('快速'), findsOneWidget);
    expect(find.text('标准'), findsOneWidget);
    expect(find.text('从容'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(settings.darkMode, isTrue);
  });

  testWidgets('统计页空态展示', (tester) async {
    final settings = await makeSettings();
    await tester.pumpWidget(wrapApp(const StatsPage(), settings: settings));
    await tester.pump();

    expect(find.text('生涯战绩'), findsOneWidget);
    expect(find.text('0 局'), findsOneWidget);
    expect(find.text('总对局'), findsOneWidget);
  });
}
