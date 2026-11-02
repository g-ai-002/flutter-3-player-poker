import 'package:flutter_3_player_poker/game/ai_player.dart';
import 'package:flutter_3_player_poker/game/combo_detector.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/models/app_settings.dart';
import 'package:flutter_3_player_poker/models/hand_record.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';
import 'package:flutter_3_player_poker/providers/game_provider.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/hand_history_service.dart';
import 'package:flutter_3_player_poker/services/log_service.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// 永远叫 3 分、也不主动出牌的 AI，用于验证兜底逻辑。
class _PassiveAi extends AiPlayer {
  @override
  int bidScore(DdzEngine engine) => 3;

  @override
  bool shouldDouble(DdzEngine engine) => false;

  @override
  List<PlayingCard>? choose(DdzEngine engine) => null;
}

/// 返回不属于手牌的牌，模拟 AI 决策异常。
class _IllegalAi extends AiPlayer {
  @override
  int bidScore(DdzEngine engine) => 3;

  @override
  bool shouldDouble(DdzEngine engine) => false;

  @override
  List<PlayingCard>? choose(DdzEngine engine) => [
    const PlayingCard(id: 999, rank: 3, suit: CardSuit.spade),
  ];
}

Future<SettingsProvider> makeSettings() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SettingsProvider(StorageService.test(prefs));
}

Future<GameProvider> aiLandlordTurn(AiPlayer ai) async {
  final settings = await makeSettings();
  final game = GameProvider(settings: settings, ai: ai, aiDelayOverride: 0);
  game.newGame();
  game.engine.currentPlayer = 0;
  game.bid(0);
  return game;
}

/// 推进定时器；轮到人类加倍时自动不加倍，直到人类出牌回合。
Future<void> pumpToHumanTurn(GameProvider game, WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    if (game.engine.phase == GamePhase.doubling &&
        game.engine.currentPlayer == 0) {
      game.doubleUp(false);
    }
    if (game.engine.phase == GamePhase.playing &&
        game.engine.currentPlayer == 0) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void takeLandlord(GameProvider game) {
  game.engine.currentPlayer = 0;
  game.bid(3);
  while (game.engine.phase == GamePhase.doubling) {
    game.engine.doubleUp(game.engine.currentPlayer, false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LogService.reset);

  testWidgets('AI 领出候选为空时兜底出最小单张', (tester) async {
    final game = await aiLandlordTurn(_PassiveAi());
    addTearDown(game.dispose);

    // 叫分 → 加倍 → AI 领出 → 另一名 AI 不出。
    await pumpToHumanTurn(game, tester);

    expect(game.engine.landlord, 1);
    expect(game.engine.phase, GamePhase.playing);
    expect(game.engine.currentPlayer, 0);
    expect(game.engine.lastCombo, isNotNull);
    expect(game.engine.players[1].hand.length, 19);
    expect(game.feedback, isNull);
    expect(
      LogService.getRecentLogs().any((line) => line.contains('兜底出最小单张')),
      isTrue,
    );
  });

  testWidgets('AI 领出非法时兜底出牌且不卡死', (tester) async {
    final game = await aiLandlordTurn(_IllegalAi());
    addTearDown(game.dispose);

    await pumpToHumanTurn(game, tester);

    expect(game.engine.landlord, 1);
    expect(game.engine.phase, GamePhase.playing);
    expect(game.engine.currentPlayer, 0);
    expect(game.engine.lastCombo, isNotNull);
    expect(game.engine.players[1].hand.length, 19);
    expect(game.feedback, isNull);

    final logs = LogService.getRecentLogs();
    expect(logs.any((line) => line.contains('AI 出牌被拒绝')), isTrue);
    expect(logs.any((line) => line.contains('兜底出最小单张')), isTrue);
  });

  test('提示无解时清空已选牌并给出反馈', () async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    game.newGame();
    takeLandlord(game);
    final hand = game.engine.players[0].hand;
    hand
      ..clear()
      ..addAll(handOf('3 4'));
    game.engine.currentPlayer = 0;
    game.engine.lastCombo = detectCombo(handOf('2'));
    game.engine.lastPlayer = 1;

    game.toggleCard(hand.first.id);
    expect(game.selectedIds, isNotEmpty);

    game.hint();
    expect(game.selectedIds, isEmpty);
    expect(game.feedback, contains('建议不出'));
  });

  test('新建对局会应用设置中的 AI 难度', () async {
    final settings = await makeSettings();
    settings.setAiLevel(AiLevel.hard);
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    game.newGame();
    expect(game.ai.level, AiLevel.hard);
    game.stop();
  });

  test('地主明牌使倍数翻倍且只能明牌一次', () async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    game.newGame();
    game.engine.currentPlayer = 0;
    game.bid(3);
    expect(game.engine.phase, GamePhase.doubling);
    expect(game.canReveal, isTrue);

    game.revealHand();
    expect(game.engine.revealed, isTrue);
    expect(game.engine.multiplier, 6);
    expect(game.canReveal, isFalse);

    game.revealHand();
    expect(game.engine.multiplier, 6);
    game.stop();
  });

  test('对局结束生成牌谱并写入历史', () async {
    final settings = await makeSettings();
    HandHistoryService.instance.resetForTest();
    final game = GameProvider(settings: settings, aiDelayOverride: 0);
    addTearDown(game.dispose);

    game.newGame();
    takeLandlord(game);
    game.engine.players[0].hand
      ..clear()
      ..addAll(handOf('3'));
    game.engine.currentPlayer = 0;
    game.engine.lastCombo = null;

    game.toggleCard(game.humanHand.single.id);
    game.playSelected();
    expect(game.engine.phase, GamePhase.finished);

    final record = game.lastRecord;
    expect(record, isNotNull);
    expect(record!.humanIsLandlord, isTrue);
    expect(record.spring, isTrue);
    expect(
      record.actions.any((action) => action.type == HandActionType.play),
      isTrue,
    );
    expect(HandHistoryService.instance.records.single.id, record.id);
  });

  test('超时领出自动打最小单张', () async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);

    game.newGame();
    takeLandlord(game);
    expect(game.isHumanTurn, isTrue);

    final before = game.humanHand.length;
    game.handleTurnTimeout();
    expect(game.humanHand.length, before - 1);
    expect(game.feedback, contains('超时'));
    expect(game.selectedIds, isEmpty);
    game.stop();
  });

  test('跟牌超时自动不出，并把回合交给下家', () async {
    final settings = await makeSettings();
    final game = GameProvider(settings: settings, aiDelayOverride: 600000);
    addTearDown(game.dispose);

    game.newGame();
    takeLandlord(game);
    game.engine.currentPlayer = 0;
    game.engine.lastCombo = detectCombo(handOf('3'));
    game.engine.lastPlayer = 1;

    game.handleTurnTimeout();
    expect(game.engine.players[0].lastPassed, isTrue);
    expect(game.engine.currentPlayer, 1);
    expect(game.feedback, contains('自动不出'));
    game.stop();
  });
}
