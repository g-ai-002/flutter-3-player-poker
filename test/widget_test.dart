import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3_player_poker/models/hand_record.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';
import 'package:flutter_3_player_poker/pages/game/game_action_bar.dart';
import 'package:flutter_3_player_poker/pages/game/game_hints.dart';
import 'package:flutter_3_player_poker/pages/game/game_overlays.dart';
import 'package:flutter_3_player_poker/pages/game/game_top_bar.dart';
import 'package:flutter_3_player_poker/pages/game/table_area.dart';
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
import 'package:flutter_3_player_poker/widgets/seat_panel.dart';
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

    final barriers = find.byType(ModalBarrier).evaluate().length;
    await tester.tap(find.byTooltip('记牌器'));
    await tester.pump();
    expect(find.text('记牌器 · 两家剩余'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('记牌器 · 两家剩余')).dy,
      lessThan(140),
      reason: '记牌器应浮在牌桌上方而不是底部弹出',
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.byType(ModalBarrier).evaluate().length,
      barriers,
      reason: '常驻浮层不应该新增遮罩挡住宿主操作',
    );

    // 点击牌桌其他位置不会收起，只有关闭按钮能关掉。
    await tester.tapAt(const Offset(8, 320));
    await tester.pump();
    expect(find.text('记牌器 · 两家剩余'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭记牌器'));
    await tester.pump();
    expect(find.text('记牌器 · 两家剩余'), findsNothing);
  });

  testWidgets('底部牌桌上显示底牌条、中央大牌与回合倒计时', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(BottomCardsBar), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(BottomCardsBar)).dy,
      lessThan(100),
      reason: '底牌位于界面顶部',
    );
    final piles = tester.widgetList<PlayedCardsView>(
      find.byType(PlayedCardsView),
    );
    expect(piles.length, 3);
    expect(piles.every((pile) => pile.cardWidth >= 40), isTrue);
    expect(find.byIcon(Icons.timer_outlined), findsWidgets);

    game.stop();
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('三家出牌区聚在牌桌中央并各自朝向座位倾斜', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // 树序：左家 2、玩家 0、右家 1。
    final rects = [
      for (var i = 0; i < 3; i++)
        tester.getRect(find.byType(PlayedCardsView).at(i)),
    ];
    for (final rect in rects) {
      expect(
        rect.center.dx,
        inInclusiveRange(780 * 0.15, 780 * 0.85),
        reason: '三家出牌区都应落在牌桌中央区域',
      );
    }
    expect(rects[0].center.dx, lessThan(rects[1].center.dx));
    expect(rects[1].center.dx, lessThan(rects[2].center.dx));
    expect(rects[0].center.dy, lessThan(rects[1].center.dy));
    expect(rects[2].center.dy, lessThan(rects[1].center.dy));
    expect(
      (rects[1].center.dx - 390).abs(),
      lessThan(24),
      reason: '玩家出牌区应在牌桌正中',
    );
    expect(
      rects[1].center.dx - rects[0].center.dx,
      lessThan(780 * 0.4),
      reason: '左右两家牌堆应与玩家牌堆靠在一起，方便比较',
    );

    double tiltOf(int id) => tester
        .widget<Transform>(find.byKey(ValueKey('pile-tilt-$id')))
        .transform
        .entry(1, 0);
    expect(tiltOf(2), lessThan(-0.05), reason: '左家出牌区朝左倾斜');
    expect(tiltOf(1), greaterThan(0.05), reason: '右家出牌区朝右倾斜');
    expect(tiltOf(0).abs(), lessThan(0.001), reason: '玩家出牌区保持水平');

    game.stop();
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('提示 / 不出 / 出牌按钮居中排列', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final passCenter = tester.getCenter(find.text('不出'));
    expect((passCenter.dx - 390).abs(), lessThan(24), reason: '按钮组应位于屏幕下方中间');
    final label = tester.getCenter(find.text('请选择要出的牌'));
    expect(label.dx, lessThan(passCenter.dx), reason: '牌型说明在按钮左侧');

    game.stop();
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('顶栏、底牌与操作条悬浮，牌桌拿满剩余空间', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final arena = tester.getRect(find.byType(GameTableArea));
    final deck = tester.getRect(find.byType(BottomCardsBar));
    final dock = tester.getRect(find.byType(GameActionBar));
    final hand = tester.getRect(find.byType(HumanHandView));

    expect(arena.top, lessThanOrEqualTo(GameTopBar.height + 0.5));
    expect(arena.height, greaterThan(360 * 0.5), reason: '小屏横屏下牌桌应拿到屏幕一半以上');
    expect(deck.top, lessThan(GameTopBar.height), reason: '底牌内嵌在悬浮顶栏');
    expect(
      dock.height,
      closeTo(GameActionBar.height, 0.01),
      reason: '操作 dock 高度固定',
    );
    expect(dock.top, closeTo(arena.bottom, 0.01), reason: '操作条紧贴牌桌下沿，不额外占位');
    expect(hand.top, closeTo(dock.bottom, 0.01), reason: '手牌区紧贴操作条');
    expect(hand.bottom, closeTo(360, 0.01), reason: '手牌贴住屏幕底部');

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('悬浮提示不推动牌桌、手牌与操作条', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final arena = tester.getRect(find.byType(GameTableArea));
    final dock = tester.getRect(find.byType(GameActionBar));
    final hand = tester.getRect(find.byType(HumanHandView));

    game.handleTurnTimeout();
    await tester.pump();
    expect(find.text('出牌超时，已自动出最小单张'), findsOneWidget);

    final toast = tester.getRect(find.byType(FeedbackToast));
    expect(toast.bottom, lessThanOrEqualTo(dock.top), reason: '提示不压住操作条与手牌');
    expect(tester.getRect(find.byType(GameTableArea)), arena);
    expect(tester.getRect(find.byType(GameActionBar)), dock);
    expect(tester.getRect(find.byType(HumanHandView)), hand);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FeedbackToast), findsNothing);
    expect(tester.getRect(find.byType(GameTableArea)), arena);

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('叫分到出牌的阶段切换不会移动牌桌', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 200);
    addTearDown(game.dispose);
    game.newGame();
    game.engine.currentPlayer = 0;

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final biddingArena = tester.getRect(find.byType(GameTableArea));
    final biddingDock = tester.getRect(find.byType(GameActionBar));

    await tester.tap(find.text('3 分'));
    await tester.pump();
    await tester.tap(find.text('不加倍'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(game.engine.phase, GamePhase.playing);

    expect(
      tester.getRect(find.byType(GameTableArea)),
      biddingArena,
      reason: '叫分 / 加倍阶段也保留同高度 dock，切到出牌不该推挤牌桌',
    );
    expect(tester.getRect(find.byType(GameActionBar)), biddingDock);

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('悬浮提示避开两侧座位与屏幕外', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    for (final size in [const Size(780, 360), const Size(360, 780)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        wrapApp(const GamePage(), settings: settings, game: game),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final chip = tester.getRect(find.byType(TurnChip));
      expect(chip.left, greaterThanOrEqualTo(0), reason: 'size $size');
      expect(chip.right, lessThanOrEqualTo(size.width), reason: 'size $size');
      expect(
        (chip.center.dx - size.width / 2).abs(),
        lessThan(12),
        reason: '轮次提示应居中悬浮: $size',
      );
      for (final seat in tester.widgetList(find.byType(SeatPanel))) {
        final rect = tester.getRect(find.byWidget(seat));
        expect(chip.overlaps(rect), isFalse, reason: '提示不应压在座位上: $size');
      }
      expect(tester.takeException(), isNull);
    }

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('极窄窗口下悬浮顶栏与操作条不溢出', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('出牌'), findsOneWidget);
    expect(
      tester.getRect(find.byType(GameActionBar)).height,
      closeTo(GameActionBar.height, 0.01),
    );

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('设置页在大屏限制最大内容宽度', (tester) async {
    final settings = await makeSettings();
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(wrapApp(const SettingsPage(), settings: settings));
    await tester.pump();

    final width = tester.getSize(find.byType(ListView)).width;
    expect(width, lessThanOrEqualTo(760));

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('手牌支持拖动连续多选', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final first = game.humanHand.first;
    final start = tester.getCenter(
      find.byKey(ValueKey('hand-card-${first.id}')),
    );
    await tester.dragFrom(start, const Offset(80, 0));
    await tester.pump();

    expect(game.selectedIds.length, greaterThanOrEqualTo(2));

    game.stop();
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('出牌倒计时归零后自动不出或领出', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('20s'), findsWidgets);

    final before = game.humanHand.length;
    await tester.pump(const Duration(seconds: 21));
    expect(game.humanHand.length, before - 1);
    expect(game.feedback, contains('超时'));

    await tester.pump(const Duration(seconds: 3));
    game.stop();
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('手机竖屏进入牌桌会锁定全屏横屏', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method.startsWith('SystemChrome.')) calls.add(call);
        return null;
      },
    );

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump();

    final orientation = calls.where(
      (call) => call.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(orientation, isNotEmpty);
    expect(
      orientation.last.arguments,
      contains('DeviceOrientation.landscapeLeft'),
    );
    expect(
      calls.any(
        (call) =>
            call.method == 'SystemChrome.setEnabledSystemUIMode' &&
            call.arguments == 'SystemUiMode.immersiveSticky',
      ),
      isTrue,
    );

    game.stop();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('右上角菜单文案使用白色，深色底上清晰可见', (tester) async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);
    game.newGame();
    takeLandlord(game);

    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pump(const Duration(milliseconds: 400));

    final item = tester.widget<Text>(find.text('重新开始'));
    expect(item.style?.color, Colors.white);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 400));
    game.stop();
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
    expect(find.text('音效'), findsOneWidget);
    expect(find.text('背景音乐'), findsOneWidget);
    expect(find.text('AI 难度'), findsOneWidget);
    expect(find.text('入门'), findsOneWidget);
    expect(find.text('高手'), findsOneWidget);
    expect(find.text('AI 思考速度'), findsOneWidget);
    expect(find.text('快速'), findsOneWidget);
    expect(find.text('标准'), findsWidgets);
    expect(find.text('从容'), findsOneWidget);
    expect(find.text('逻辑更新速率'), findsOneWidget);
    expect(find.text('30Hz'), findsOneWidget);
    expect(find.text('60Hz'), findsOneWidget);
    expect(find.text('120Hz'), findsOneWidget);

    await tester.tap(find.text('高手'));
    await tester.pump();
    expect(settings.aiLevel, AiLevel.hard);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(settings.darkMode, isTrue);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();
    expect(settings.soundEnabled, isFalse);

    // 选项位于列表下方，先滚动到可见区域再点击。
    await tester.ensureVisible(find.text('120Hz'));
    await tester.pump();
    await tester.tap(find.text('120Hz'));
    await tester.pump();
    expect(settings.logicRate, LogicRate.hz120);
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
    expect(find.text('复盘'), findsOneWidget);
    expect(find.text('复制牌谱'), findsOneWidget);
  });
}
