import 'package:flutter/material.dart';
import 'package:flutter_3_player_poker/models/hand_record.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';
import 'package:flutter_3_player_poker/pages/game/game_overlays.dart';
import 'package:flutter_3_player_poker/pages/game_page.dart';
import 'package:flutter_3_player_poker/pages/hand_history_page.dart';
import 'package:flutter_3_player_poker/pages/hand_record_page.dart';
import 'package:flutter_3_player_poker/pages/home_page.dart';
import 'package:flutter_3_player_poker/pages/settings_page.dart';
import 'package:flutter_3_player_poker/pages/stats_page.dart';
import 'package:flutter_3_player_poker/providers/game_provider.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/hand_history_service.dart';
import 'package:flutter_3_player_poker/services/stats_service.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_3_player_poker/theme/app_theme.dart';
import 'package:flutter_3_player_poker/widgets/played_cards_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/models/app_settings.dart';

Future<SettingsProvider> makeSettings() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SettingsProvider(StorageService.test(prefs));
}

/// 玩家叫 3 分成为地主，三方不加倍，直接进入出牌阶段。
void takeLandlord(GameProvider game) {
  game.engine.currentPlayer = 0;
  game.bid(3);
  while (game.engine.phase == GamePhase.doubling) {
    game.engine.doubleUp(game.engine.currentPlayer, false);
  }
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
    HandHistoryService.instance.resetForTest();
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
    expect(find.text('牌谱'), findsOneWidget);
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
    takeLandlord(game);

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
    takeLandlord(game);

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

  testWidgets('牌桌可打开记牌器面板', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('记牌器 · 两家剩余'), findsNothing);

    await tester.tap(find.byTooltip('记牌器'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('记牌器 · 两家剩余'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('记牌器 · 两家剩余'), findsNothing);
  });

  testWidgets('出牌区在窄屏展示长牌型不溢出', (tester) async {
    final cards = [
      for (var i = 0; i < 20; i++)
        PlayingCard(id: i, rank: 3 + i % 12, suit: CardSuit.spade),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 72, child: PlayedCardsView(cards: cards)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('牌桌在平板与桌面尺寸无溢出', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    for (final size in [
      const Size(768, 1024),
      const Size(1024, 1366),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        wrapApp(const GamePage(), settings: settings, game: game),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text('出牌'), findsOneWidget);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('结算浮层展示三家得分与再来一局', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    game.newGame();
    takeLandlord(game);
    game.engine.players[0].hand
      ..clear()
      ..add(game.engine.bottomCards.first);
    game.engine.currentPlayer = 0;
    game.engine.lastCombo = null;
    game.toggleCard(game.engine.players[0].hand.first.id);
    game.playSelected();

    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('再来一局'), findsOneWidget);
    expect(find.text('返回主页'), findsOneWidget);
    expect(find.text('你 · 地主'), findsOneWidget);
    expect(find.text('小智'), findsWidgets);
    expect(find.text('阿福'), findsWidgets);
    expect(find.byType(ScoreBoard), findsOneWidget);
    expect(find.text('+12'), findsNWidgets(2));
    expect(find.text('-6'), findsNWidgets(2));
    expect(find.text('查看本局牌谱'), findsOneWidget);
  });

  testWidgets('小屏横屏结算浮层可滚动且无溢出', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);
    game.engine.players[0].hand
      ..clear()
      ..add(game.engine.bottomCards.first);
    game.engine.currentPlayer = 0;
    game.engine.lastCombo = null;
    game.toggleCard(game.humanHand.single.id);
    game.playSelected();

    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('再来一局'), findsOneWidget);
    expect(find.text('查看本局牌谱'), findsOneWidget);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('设置页展示主题、AI 难度与速度选项', (tester) async {
    final settings = await makeSettings();
    await tester.pumpWidget(wrapApp(const SettingsPage(), settings: settings));
    await tester.pump();

    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('AI 难度'), findsOneWidget);
    expect(find.text('入门'), findsOneWidget);
    expect(find.text('高手'), findsOneWidget);
    expect(find.text('AI 思考速度'), findsOneWidget);
    expect(find.text('快速'), findsOneWidget);
    expect(find.text('标准'), findsWidgets);
    expect(find.text('从容'), findsOneWidget);

    await tester.tap(find.text('高手'));
    await tester.pump();
    expect(settings.aiLevel, AiLevel.hard);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(settings.darkMode, isTrue);
  });

  testWidgets('叫分浮层展示分档并可直接叫 3 分', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 10000);
    addTearDown(game.dispose);
    game.newGame();
    game.engine.currentPlayer = 0;

    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('轮到你叫分'), findsWidgets);
    expect(find.text('不叫'), findsOneWidget);
    expect(find.text('1 分'), findsOneWidget);
    expect(find.text('2 分'), findsOneWidget);
    expect(find.text('3 分'), findsOneWidget);

    await tester.tap(find.text('3 分'));
    await tester.pump();

    expect(game.engine.landlord, 0);
    expect(game.engine.baseScore, 3);
    expect(find.text('是否加倍？'), findsWidgets);

    await tester.tap(find.text('不加倍'));
    await tester.pump();
    expect(game.engine.phase, GamePhase.doubling);
    expect(game.engine.currentPlayer, 1);
    expect(game.engine.multiplier, 3);
    expect(find.text('是否加倍？'), findsNothing);
    game.stop();
  });

  testWidgets('统计页空态展示', (tester) async {
    final settings = await makeSettings();
    await tester.pumpWidget(wrapApp(const StatsPage(), settings: settings));
    await tester.pump();

    expect(find.text('生涯战绩'), findsOneWidget);
    expect(find.text('0 局'), findsOneWidget);
    expect(find.text('总对局'), findsOneWidget);
  });

  testWidgets('地主可在加倍前明牌，倍数同步翻倍', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 10000);
    addTearDown(game.dispose);
    game.newGame();
    game.engine.currentPlayer = 0;
    game.bid(3);

    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('是否加倍？'), findsWidgets);
    expect(find.text('明牌 ×2（亮出全部手牌）'), findsOneWidget);

    await tester.tap(find.text('明牌 ×2（亮出全部手牌）'));
    await tester.pump();

    expect(game.engine.revealed, isTrue);
    expect(game.engine.multiplier, 6);
    expect(find.text('已明牌 · 倍数 ×2'), findsOneWidget);
    game.stop();
  });

  testWidgets('AI 地主明牌后牌桌展示标记并可查看手牌', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 10000);
    addTearDown(game.dispose);
    game.newGame();
    game.engine.currentPlayer = 1;
    game.engine.bid(1, 3);
    game.engine.revealHand(1);
    while (game.engine.phase == GamePhase.doubling) {
      game.engine.doubleUp(game.engine.currentPlayer, false);
    }

    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('地主已明牌 · 点击其座位查看手牌'), findsOneWidget);
    expect(find.text('明牌'), findsOneWidget);

    await tester.tap(find.text('明牌'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('小智 · 明牌'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    game.stop();
  });

  testWidgets('牌谱页空态与详情展示', (tester) async {
    final settings = await makeSettings();

    await tester.pumpWidget(
      wrapApp(const HandHistoryPage(), settings: settings),
    );
    await tester.pump();
    expect(find.text('还没有牌谱'), findsOneWidget);

    final record = HandRecord(
      id: 'demo',
      startedAt: DateTime(2026, 11, 1, 21),
      endedAt: DateTime(2026, 11, 1, 21, 8),
      humanIsLandlord: true,
      landlordName: '你',
      landlordWon: true,
      baseScore: 3,
      multiplier: 6,
      spring: false,
      antiSpring: false,
      revealed: true,
      scores: const [12, -6, -6],
      playerNames: const ['你', '小智', '阿福'],
      bottomCards: const [],
      actions: const [
        HandAction(player: 0, type: HandActionType.bid, text: '你 叫 3 分'),
        HandAction(player: 0, type: HandActionType.reveal, text: '你 明牌，倍数 ×6'),
      ],
    );
    await tester.pumpWidget(
      wrapApp(HandRecordPage(record: record), settings: settings),
    );
    await tester.pump();

    expect(find.text('牌谱详情'), findsOneWidget);
    expect(find.text('出牌记录'), findsOneWidget);
    expect(find.text('你 叫 3 分'), findsOneWidget);
    expect(find.text('你 明牌，倍数 ×6'), findsOneWidget);
    expect(find.text('复制牌谱'), findsOneWidget);
  });
}
