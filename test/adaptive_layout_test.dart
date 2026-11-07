import 'package:flutter/material.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/pages/game/game_hints.dart';
import 'package:flutter_3_player_poker/pages/game_page.dart';
import 'package:flutter_3_player_poker/pages/home_page.dart';
import 'package:flutter_3_player_poker/providers/game_provider.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/hand_history_service.dart';
import 'package:flutter_3_player_poker/services/stats_service.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_3_player_poker/theme/app_theme.dart';
import 'package:flutter_3_player_poker/widgets/hand_view.dart';
import 'package:flutter_3_player_poker/widgets/played_cards_view.dart';
import 'package:flutter_3_player_poker/widgets/seat_panel.dart';
import 'package:flutter_3_player_poker/widgets/table_overlay.dart';
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

void takeLandlord(GameProvider game) {
  game.engine.currentPlayer = 0;
  game.bid(3);
  while (game.engine.phase == GamePhase.doubling) {
    game.engine.doubleUp(game.engine.currentPlayer, false);
  }
}

Future<GameProvider> playingGame(SettingsProvider settings) async {
  final game = GameProvider(settings: settings, aiDelayOverride: 600000);
  game.newGame();
  takeLandlord(game);
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StatsService.instance.resetForTest();
    HandHistoryService.instance.resetForTest();
  });

  testWidgets('主页宽屏改为双栏，主视觉与入口分列两侧', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const HomePage(), settings: settings, game: game),
    );
    await tester.pump();

    final start = tester.getRect(find.text('开始对局'));
    final title = tester.getRect(find.text('斗地主'));
    expect(start.center.dx, greaterThan(900), reason: '入口应落在右栏');
    expect(title.center.dx, lessThan(600), reason: '主视觉应落在左栏');
    expect(start.bottom, lessThan(900), reason: '大屏无需滚动即可开局');
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('主页在手机横屏无需滚动即可开局', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    for (final size in const [Size(780, 360), Size(568, 320)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        wrapApp(const HomePage(), settings: settings, game: game),
      );
      await tester.pump();

      final start = tester.getRect(find.text('开始对局'));
      expect(start.top, greaterThanOrEqualTo(0), reason: 'size $size');
      expect(
        start.bottom,
        lessThanOrEqualTo(size.height),
        reason: '横屏开局按钮必须在首屏内: $size',
      );
      expect(find.text('玩法说明'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'size $size');
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('主页在窄屏保持单列且不溢出', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    for (final size in const [Size(320, 568), Size(390, 844), Size(673, 841)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        wrapApp(const HomePage(), settings: settings, game: game),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text('开始对局'), findsOneWidget);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('窄屏手牌保留可读的点数角标', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final cards = game.humanHand;
    expect(cards.length, 20);
    final first = tester.getRect(
      find.byKey(ValueKey('hand-card-${cards[0].id}')),
    );
    final second = tester.getRect(
      find.byKey(ValueKey('hand-card-${cards[1].id}')),
    );
    final strip = second.left - first.left;
    expect(
      strip / first.width,
      greaterThanOrEqualTo(0.33),
      reason: '露出的牌宽至少要能放下点数角标',
    );
    final hand = tester.getRect(find.byType(HandView));
    expect(hand.right, lessThanOrEqualTo(360), reason: '手牌不能超出屏幕');

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('出牌区在大屏按比例放大牌面', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    Future<double> pileWidthAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        wrapApp(const GamePage(), settings: settings, game: game),
      );
      await tester.pump(const Duration(milliseconds: 60));
      return tester
          .widgetList<PlayedCardsView>(find.byType(PlayedCardsView))
          .first
          .cardWidth;
    }

    expect(await pileWidthAt(const Size(780, 360)), closeTo(48.75, 0.01));
    expect(await pileWidthAt(const Size(1440, 900)), greaterThanOrEqualTo(86));
    expect(await pileWidthAt(const Size(3840, 2160)), greaterThanOrEqualTo(90));
    expect(await pileWidthAt(const Size(3840, 2160)), lessThanOrEqualTo(96));

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('牌桌在手机 / 折叠屏 / 平板 / 超宽屏均无溢出', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    for (final size in const [
      Size(320, 568),
      Size(360, 780),
      Size(568, 320),
      Size(600, 960),
      Size(673, 841),
      Size(768, 1024),
      Size(1024, 768),
      Size(1280, 720),
      Size(1440, 900),
      Size(2560, 1440),
      Size(3440, 1440),
      Size(3840, 2160),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        wrapApp(const GamePage(), settings: settings, game: game),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text('出牌'), findsOneWidget, reason: 'size $size');
      final hand = tester.getRect(find.byType(HandView));
      expect(hand.right, lessThanOrEqualTo(size.width), reason: 'size $size');
      expect(hand.bottom, lessThanOrEqualTo(size.height), reason: 'size $size');
    }

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('竖屏提示不压座位与两家出牌区', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final chip = tester.getRect(find.byType(TurnChip));
    expect(chip.width, greaterThan(130), reason: '竖屏提示保留单行完整宽度');
    for (final seat in tester.widgetList<SeatPanel>(find.byType(SeatPanel))) {
      expect(chip.overlaps(tester.getRect(find.byWidget(seat))), isFalse);
    }
    // 树序：左家 2、玩家 0、右家 1。
    for (final index in const [0, 2]) {
      final pile = tester.getRect(find.byType(PlayedCardsView).at(index));
      expect(chip.overlaps(pile), isFalse, reason: '不压对手出牌区');
    }
    expect(find.byType(GameHints), findsOneWidget);

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('竖屏三家出牌区聚在牌桌中央且朝向座位', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    // 树序：左家 2、玩家 0、右家 1。
    final rects = [
      for (var i = 0; i < 3; i++)
        tester.getRect(find.byType(PlayedCardsView).at(i)),
    ];
    for (final rect in rects) {
      expect(
        rect.center.dx,
        inInclusiveRange(360 * 0.15, 360 * 0.85),
        reason: '竖屏三家出牌区也应落在牌桌中央',
      );
    }
    expect(rects[0].center.dx, lessThan(rects[1].center.dx));
    expect(rects[1].center.dx, lessThan(rects[2].center.dx));
    expect(rects[0].center.dy, lessThan(rects[1].center.dy));
    expect(rects[2].center.dy, lessThan(rects[1].center.dy));
    expect(rects[0].left, greaterThan(20), reason: '左家牌堆不贴屏幕边缘');
    expect(rects[2].right, lessThan(340), reason: '右家牌堆不贴屏幕边缘');

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('横屏刘海安全区不被顶栏与浮层占用', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);
    game.newGame();
    game.engine.currentPlayer = 0;

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 32, right: 32, top: 6);
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final topBar = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'GameTopBar',
      ),
    );
    expect(topBar.left, greaterThanOrEqualTo(32), reason: '顶栏避开左侧挖孔');
    expect(topBar.right, lessThanOrEqualTo(748), reason: '顶栏避开右侧挖孔');

    final panel = tester.getRect(find.byType(TablePanel));
    expect(panel.left, greaterThanOrEqualTo(32));
    expect(panel.right, lessThanOrEqualTo(748));
    expect(tester.takeException(), isNull);

    game.stop();
    tester.view.resetPadding();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
