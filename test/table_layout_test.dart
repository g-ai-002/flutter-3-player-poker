import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/pages/game/game_action_bar.dart';
import 'package:flutter_3_player_poker/pages/game/game_hints.dart';
import 'package:flutter_3_player_poker/pages/game/game_layout.dart';
import 'package:flutter_3_player_poker/pages/game/game_top_bar.dart';
import 'package:flutter_3_player_poker/pages/game/table_area.dart';
import 'package:flutter_3_player_poker/pages/game_page.dart';
import 'package:flutter_3_player_poker/providers/game_provider.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/audio_service.dart';
import 'package:flutter_3_player_poker/services/hand_history_service.dart';
import 'package:flutter_3_player_poker/services/stats_service.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_3_player_poker/theme/app_theme.dart';
import 'package:flutter_3_player_poker/utils/screen_mode.dart';
import 'package:flutter_3_player_poker/widgets/played_cards_view.dart';
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

/// 玩家叫 3 分成为地主，三方不加倍，直接进入出牌阶段。
Future<GameProvider> playingGame(SettingsProvider settings) async {
  final game = GameProvider(settings: settings, aiDelayOverride: 600000);
  game.newGame();
  game.engine.currentPlayer = 0;
  game.bid(3);
  while (game.engine.phase == GamePhase.doubling) {
    game.engine.doubleUp(game.engine.currentPlayer, false);
  }
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StatsService.instance.resetForTest();
    HandHistoryService.instance.resetForTest();
  });

  group('牌桌网格比例决定屏幕方向', () {
    test('长屏手机横屏能放下更大的网格，自动横屏', () {
      for (final size in const [
        Size(360, 780),
        Size(390, 844),
        Size(412, 915),
      ]) {
        expect(prefersLandscape(size), isTrue, reason: '$size 应横屏');
        expect(tableOrientationLock(size), isTrue, reason: '$size 应锁定横屏');
      }
    });

    test('矮屏手机横屏后高度不足，保持竖屏', () {
      const size = Size(320, 568);
      expect(prefersLandscape(size), isFalse);
      expect(tableOrientationLock(size), isFalse, reason: '应锁定竖屏');
    });

    test('平板与折叠屏保留系统方向', () {
      for (final size in const [Size(768, 1024), Size(673, 841)]) {
        expect(tableOrientationLock(size), isNull, reason: '$size 不应锁定方向');
      }
    });

    test('网格按设计比例缩放，纵向留白不放大牌面', () {
      final wide = tableGridWidth(const Size(1440, 900), chrome: 200);
      final tall = tableGridWidth(const Size(900, 1440), chrome: 200);
      expect(wide, greaterThan(tall), reason: '宽屏能放下更大的横向网格');
      expect(
        tableGridWidth(const Size(100, 100), chrome: 200),
        0,
        reason: '高度不足时不返回负数',
      );
    });
  });

  testWidgets('手机进入牌桌按网格比例锁定竖屏全屏', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method.startsWith('SystemChrome.')) calls.add(call);
        return null;
      },
    );

    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump();

    final orientation = calls.lastWhere(
      (call) => call.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(orientation.arguments, contains('DeviceOrientation.portraitUp'));
    expect(
      calls.any(
        (call) =>
            call.method == 'SystemChrome.setEnabledSystemUIMode' &&
            call.arguments == 'SystemUiMode.immersiveSticky',
      ),
      isTrue,
      reason: '竖屏也进入沉浸式全屏',
    );

    game.stop();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('宽屏把提示分列到网格左右两侧', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);
    // 对手只剩 1 张：左侧出现残局提醒。
    game.engine.players[1].hand.removeRange(
      1,
      game.engine.players[1].hand.length,
    );
    game.toggleCard(game.humanHand.first.id);
    game.toggleCard(game.humanHand.first.id);

    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(GameLayout.sideHints(1024), isTrue);
    final hints = tester.widget<GameHints>(find.byType(GameHints));
    expect(hints.sides, isTrue, reason: '宽屏应启用左右两侧提示');

    // 触发一条临时反馈：未选牌直接点出牌会被拒绝。
    game.playSelected();
    await tester.pump(const Duration(milliseconds: 60));

    final toast = tester.getRect(find.byType(FeedbackToast));
    final chip = tester.getRect(find.byType(TurnChip));
    final arena = tester.getRect(find.byType(GameTableArea));
    expect(toast.center.dx, greaterThan(1024 * 0.8), reason: '反馈贴在网格右侧');
    expect(chip.center.dx, closeTo(1024 / 2, 1), reason: '轮次胶囊在网格正上方');
    expect(chip.top, lessThan(arena.top + 4), reason: '胶囊悬浮在网格上沿');

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('宽屏牌局进度信息居中显示', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);
    game.engine.lastActionText = '两家不出，你 重新领出';
    game.engine.players[1].hand.removeRange(
      1,
      game.engine.players[1].hand.length,
    );

    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final progress = tester.getRect(find.text('两家不出，你 重新领出'));
    final chip = tester.getRect(find.byType(TurnChip));
    final arena = tester.getRect(find.byType(GameTableArea));
    expect(progress.center.dx, closeTo(1024 / 2, 1), reason: '上一手进度在正上方居中');
    expect(
      progress.top,
      greaterThanOrEqualTo(chip.bottom),
      reason: '进度紧跟在轮次下方',
    );
    expect(
      progress.bottom,
      lessThanOrEqualTo(arena.top + GameLayout.hintBand(sides: true)),
      reason: '居中的进度落在网格上方的提示带内',
    );

    final alert = tester.getRect(find.text('小智只剩 1 张 · 出大牌压制'));
    expect(alert.center.dx, lessThan(1024 * 0.2), reason: '残局提醒仍在网格左侧');

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('窄屏提示叠在网格上方，不压出牌区', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(GameLayout.sideHints(390), isFalse);
    final hints = tester.widget<GameHints>(find.byType(GameHints));
    expect(hints.sides, isFalse);

    final chip = tester.getRect(find.byType(TurnChip));
    final arena = tester.getRect(find.byType(GameTableArea));
    expect(chip.center.dx, closeTo(390 / 2, 1));
    expect(
      chip.bottom,
      lessThanOrEqualTo(arena.top + GameLayout.stackedHintBand),
      reason: '胶囊落在预留的提示带内',
    );
    for (final pile in tester.widgetList<PlayedCardsView>(
      find.byType(PlayedCardsView),
    )) {
      expect(chip.overlaps(tester.getRect(find.byWidget(pile))), isFalse);
    }

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('网格居中且提示带不让牌桌移位', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final before = tester.getRect(find.byType(GameTableArea));
    final upper = tester.getRect(find.byType(GameTopBar));

    game.playSelected();
    await tester.pump(const Duration(milliseconds: 60));
    game.pass();
    await tester.pump(const Duration(milliseconds: 60));

    expect(
      tester.getRect(find.byType(GameTableArea)),
      before,
      reason: '提示与出牌都不应推动牌桌',
    );
    expect(before.top, closeTo(GameTopBar.height, 0.01));
    expect(before.top, greaterThanOrEqualTo(upper.bottom));
    final dock = tester.getRect(find.byType(GameActionBar));
    final hand = tester.getRect(find.byType(HumanHandView));
    expect(before.bottom, closeTo(dock.top, 0.01), reason: '操作 dock 紧贴网格下沿');
    expect(hand.bottom, closeTo(360, 0.01), reason: '手牌悬浮在屏幕最下方');

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('离开牌桌后不残留定时器、事件订阅与背景音乐', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    tester.view.physicalSize = const Size(780, 360);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      wrapApp(const GamePage(), settings: settings, game: game),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(game.events.listenerCount, 1, reason: 'Flame 场景已订阅事件');
    expect(AudioService.instance.bgmRequested, isTrue, reason: '牌桌应请求背景音乐');
    // 轮到 AI：调度一个待触发的思考定时器。
    game.engine.currentPlayer = 1;
    game.driver.schedule();
    expect(game.driver.isScheduled, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(game.events.listenerCount, 0, reason: '牌桌销毁后应退订事件');
    expect(game.driver.isScheduled, isFalse, reason: 'AI 定时器应被取消');
    expect(game.thinkingPlayer, isNull);
    expect(game.phase, GamePhase.idle, reason: '对局收尾为 idle');
    expect(AudioService.instance.bgmRequested, isFalse, reason: '背景音乐应停止');
    expect(tester.binding.transientCallbackCount, 0, reason: '不应残留动画回调');

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
