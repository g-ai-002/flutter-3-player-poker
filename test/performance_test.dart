import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3_player_poker/game/ddz_table_game.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/game/play_flight.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';
import 'package:flutter_3_player_poker/pages/game/table_area.dart';
import 'package:flutter_3_player_poker/providers/game_provider.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/audio_service.dart';
import 'package:flutter_3_player_poker/services/hand_history_service.dart';
import 'package:flutter_3_player_poker/services/stats_service.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_3_player_poker/theme/app_theme.dart';
import 'package:flutter_3_player_poker/widgets/hand_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Widget wrapGame(Widget home, GameProvider game) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: game.settings),
      ChangeNotifierProvider.value(value: game),
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

  group('选牌局部刷新', () {
    test('点选只更新选牌小对象，不通知整页重建', () async {
      final settings = await makeSettings();
      final game = GameProvider(settings: settings, aiDelayOverride: 600000);
      addTearDown(game.dispose);
      game.newGame();
      takeLandlord(game);

      var pageRebuilds = 0;
      var selectionEvents = 0;
      game.addListener(() => pageRebuilds++);
      game.selection.addListener(() => selectionEvents++);

      final card = game.humanHand.first;
      game.toggleCard(card.id);

      expect(game.selectedIds, {card.id});
      expect(selectionEvents, 1, reason: '手牌与操作条据此局部刷新');
      expect(pageRebuilds, 0, reason: '选牌不应重建整张牌桌页');

      game.setSelection([card.id]);
      expect(selectionEvents, 1, reason: '选牌没变化时不重复通知');

      game.setSelection(const []);
      expect(selectionEvents, 2);
      expect(pageRebuilds, 0);

      game.stop();
    });

    test('选牌快照不可变，订阅者拿到后不会被后续操作改掉', () async {
      final settings = await makeSettings();
      final game = GameProvider(settings: settings, aiDelayOverride: 600000);
      addTearDown(game.dispose);
      game.newGame();
      takeLandlord(game);

      final card = game.humanHand.first;
      game.toggleCard(card.id);
      final snapshot = game.selectedIds;
      expect(() => snapshot.add(999), throwsUnsupportedError);

      game.toggleCard(card.id);
      expect(snapshot, {card.id}, reason: '旧快照保留当时的选牌');
      expect(game.selectedIds, isEmpty);

      game.stop();
    });

    testWidgets('每张手牌独立成层，选中只影响自己的重绘', (tester) async {
      final cards = PlayingCard.createDeck().take(3).toList();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HandView(
              cards: cards,
              selectedIds: {cards[1].id},
              onTap: (_) {},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );

      for (final card in cards) {
        final slot = find.byKey(ValueKey('hand-card-${card.id}'));
        expect(slot, findsOneWidget);
        expect(
          find.descendant(of: slot, matching: find.byType(RepaintBoundary)),
          findsOneWidget,
          reason: '每张牌各自重绘，不连带十几张阴影一起重画',
        );
      }
    });
  });

  group('牌面绘制缓存', () {
    tearDown(CardArt.clearCache);

    test('同一张牌只合成一次图片，牌背单独复用', () {
      const ace = PlayingCard(id: 0, rank: 14, suit: CardSuit.spade);
      const king = PlayingCard(id: 1, rank: 13, suit: CardSuit.heart);

      final first = CardArt.face(ace);
      expect(identical(CardArt.face(ace), first), isTrue);
      expect(identical(CardArt.face(king), first), isFalse);
      expect(CardArt.cachedFaces, 2);
      expect(identical(CardArt.back(), CardArt.back()), isTrue);
      expect(CardArt.pictureOf(null), same(CardArt.back()));
    });

    test('缓存图片能直接画进画布，释放后清空', () {
      const card = PlayingCard(id: 7, rank: 17, suit: CardSuit.joker);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawPicture(CardArt.face(card));
      canvas.drawPicture(CardArt.back());
      final picture = recorder.endRecording();
      expect(picture.approximateBytesUsed, greaterThan(0));
      picture.dispose();

      CardArt.clearCache();
      expect(CardArt.cachedFaces, 0);
    });
  });

  group('背景音乐合成', () {
    test('波形是 12 秒的合法 WAV，可在后台 isolate 生成', () async {
      final sync = buildBgmLoopWav();
      expect(String.fromCharCodes(sync.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(sync.sublist(8, 12)), 'WAVE');
      expect(sync.length, lessThan(600 * 1024));

      final background = await compute(buildBgmLoopWav, null);
      expect(background.length, sync.length);
      expect(background.sublist(0, 44), sync.sublist(0, 44));
    });
  });

  group('出牌区几何去抖', () {
    test('几何按值比较，同中心同尺寸视为未变化', () {
      const a = PileTarget(
        center: Offset(0.5, 0.5),
        cardSize: Size(40, 56),
        maxWidth: 200,
      );
      const b = PileTarget(
        center: Offset(0.5, 0.5),
        cardSize: Size(40, 56),
        maxWidth: 200,
      );
      const c = PileTarget(
        center: Offset(0.5, 0.5),
        cardSize: Size(41, 57.4),
        maxWidth: 200,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    testWidgets('同尺寸重建不再重复回传牌堆几何', (tester) async {
      final settings = await makeSettings();
      final game = GameProvider(settings: settings, aiDelayOverride: 600000);
      addTearDown(game.dispose);
      game.newGame();
      takeLandlord(game);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var reports = 0;
      Widget build() => wrapGame(
        Scaffold(
          body: GameTableArea(
            provider: game,
            landscape: false,
            onPileTargets: (_) => reports++,
          ),
        ),
        game,
      );

      await tester.pumpWidget(build());
      await tester.pump();
      expect(reports, 1);

      await tester.pumpWidget(build());
      await tester.pump();
      expect(reports, 1, reason: '几何没变时跳过布局回传');

      game.stop();
    });
  });
}
