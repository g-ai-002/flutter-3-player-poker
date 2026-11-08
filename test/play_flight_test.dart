import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3_player_poker/game/ddz_table_game.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/game/play_flight.dart';
import 'package:flutter_3_player_poker/game/table_events.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';
import 'package:flutter_3_player_poker/pages/game/table_area.dart';
import 'package:flutter_3_player_poker/providers/game_provider.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_3_player_poker/theme/app_theme.dart';
import 'package:flutter_3_player_poker/widgets/played_cards_view.dart';
import 'package:flutter_3_player_poker/widgets/playing_card_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> makeSettings() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SettingsProvider(StorageService.test(prefs));
}

Widget wrapApp(Widget home, GameProvider game) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: game.settings),
      ChangeNotifierProvider.value(value: game),
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

  group('飞牌节拍与出牌区几何', () {
    test('牌越多动画越长，牌堆等动画落定后再亮出', () {
      expect(PlayFlight.total(0), 0);
      expect(PlayFlight.total(1), closeTo(0.32, 0.001));
      expect(PlayFlight.total(5), closeTo(0.32 + 0.035 * 4, 0.001));
      expect(PlayFlight.total(12), greaterThan(PlayFlight.total(5)));
      expect(
        PlayFlight.revealDelay(5).inMilliseconds,
        greaterThan((PlayFlight.total(5) * 1000).round()),
      );
    });

    test('单张牌不叠放，多张牌按牌宽与可用宽度收敛间距', () {
      expect(
        PlayFlight.spacing(count: 1, cardWidth: 48, maxWidth: 200),
        0,
      );
      expect(
        PlayFlight.spacing(count: 5, cardWidth: 48, maxWidth: 400),
        closeTo(48 * 0.62, 0.001),
        reason: '牌桌够宽时按牌宽叠放',
      );
      expect(
        PlayFlight.spacing(count: 20, cardWidth: 48, maxWidth: 200),
        closeTo((200 - 48) / 19, 0.001),
        reason: '牌堆挤满时压缩到可用宽度内',
      );
    });
  });

  test('出牌动画的牌数、尺寸与落点跟出牌区一致', () async {
    final bus = TableEventBus();
    final game = DdzTableGame(bus: bus);
    game.onGameResize(Vector2(800, 600));
    await game.onLoad();

    const cardSize = Size(50, 70);
    game.setPileTargets({
      1: const PileTarget(
        center: Offset(0.8, 0.3),
        cardSize: cardSize,
        maxWidth: 208,
        angle: 0.14,
      ),
    });
    final cards = [
      for (var i = 0; i < 12; i++)
        PlayingCard(id: i, rank: 3 + i % 12, suit: CardSuit.spade),
    ];
    bus.emit(
      TableEvent(type: TableEventType.play, player: 1, cards: cards),
    );
    game.update(0.02);

    final flights = game.children.whereType<CardFlight>().toList();
    expect(flights.length, cards.length, reason: '飞牌数量必须与出牌对得上');
    for (final flight in flights) {
      expect(flight.size, cardSize, reason: '落定时应等于出牌区的牌面尺寸');
      expect(flight.angle, closeTo(0.14, 0.0001));
    }
    expect(flights.first.to.dy, closeTo(600 * 0.3, 0.01));
    final spacing = PlayFlight.spacing(
      count: cards.length,
      cardWidth: cardSize.width,
      maxWidth: 208,
    );
    expect(
      flights.last.to.dx - flights.first.to.dx,
      closeTo(spacing * (cards.length - 1), 0.01),
      reason: '落点按出牌区的叠放间距排开',
    );
  });

  testWidgets('出牌后牌堆等飞牌落定才亮出', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    final card = game.humanHand.last;
    game.toggleCard(card.id);
    game.playSelected();

    expect(game.isPlayFlying(0), isTrue, reason: '出牌瞬间牌堆先收起');
    expect(game.engine.players[0].lastPlay, hasLength(1));
    await tester.pump(PlayFlight.revealDelay(1));
    expect(game.isPlayFlying(0), isFalse, reason: '动画结束后牌堆亮出');

    game.stop();
  });

  testWidgets('牌桌回传的出牌区尺寸与实际牌面一致', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    game.engine.players[0].lastPlay = [
      for (var i = 0; i < 5; i++)
        PlayingCard(id: 100 + i, rank: 4 + i, suit: CardSuit.heart),
    ];

    Map<int, PileTarget>? targets;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: game),
          ],
          child: Scaffold(
            body: GameTableArea(
              provider: game,
              landscape: false,
              onPileTargets: (value) => targets = value,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(targets, isNotNull);
    final human = targets![0]!;
    expect(human.cardSize.width, closeTo(1200 / 16, 0.5));
    expect(
      human.cardSize.height,
      closeTo(human.cardSize.width * PlayFlight.cardAspect, 0.5),
    );
    expect(human.center.dx, closeTo(0.5, 0.05), reason: '玩家牌堆居中');
    expect(human.center.dy, greaterThan(0.5), reason: '玩家牌堆在网格下方');
    expect(human.angle, 0, reason: '玩家牌堆保持水平');
    expect(targets![2]!.angle, lessThan(0), reason: '左家朝自家座位倾斜');
    expect(targets![1]!.angle, greaterThan(0), reason: '右家朝自家座位倾斜');

    // 回传的牌面尺寸必须等于牌桌真正画出来的牌宽，飞牌才能严丝合缝地接手。
    final pile = find.byType(PlayedCardsView).at(1);
    final pileCards = find.descendant(
      of: pile,
      matching: find.byType(PlayingCardView),
    );
    final first = tester.getRect(pileCards.first);
    final last = tester.getRect(pileCards.last);
    expect(first.width, closeTo(human.cardSize.width, 0.5));
    expect(first.height, closeTo(human.cardSize.height, 0.5));
    expect(first.center.dy, closeTo(human.center.dy * 800, 1));
    expect(
      (first.center.dx + last.center.dx) / 2,
      closeTo(human.center.dx * 1200, 1),
      reason: '回传的中心就是整堆牌的中心',
    );

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('高像素密度屏幕按逻辑像素回传牌面尺寸', (tester) async {
    final settings = await makeSettings();
    final game = await playingGame(settings);
    addTearDown(game.dispose);

    Map<int, PileTarget>? targets;
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: GameTableArea(
            provider: game,
            landscape: false,
            onPileTargets: (value) => targets = value,
          ),
        ),
        game,
      ),
    );
    await tester.pump();

    expect(targets, isNotNull);
    // 牌桌层用的是逻辑像素，2 倍屏上不能把牌面尺寸算成两倍。
    expect(targets![0]!.cardSize.width, closeTo(1200 / 16, 0.5));

    game.stop();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
