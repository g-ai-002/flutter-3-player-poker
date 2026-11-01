import 'package:flutter_3_player_poker/game/ai_player.dart';
import 'package:flutter_3_player_poker/game/combo_detector.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';
import 'package:flutter_3_player_poker/providers/game_provider.dart';
import 'package:flutter_3_player_poker/providers/settings_provider.dart';
import 'package:flutter_3_player_poker/services/log_service.dart';
import 'package:flutter_3_player_poker/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// 永远不叫地主、也不主动出牌的 AI，用于验证兜底逻辑。
class _PassiveAi extends AiPlayer {
  @override
  bool shouldCall(List<PlayingCard> hand) => true;

  @override
  List<PlayingCard>? choose(DdzEngine engine) => null;
}

/// 返回不属于手牌的牌，模拟 AI 决策异常。
class _IllegalAi extends AiPlayer {
  @override
  bool shouldCall(List<PlayingCard> hand) => true;

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
  game.bid(false);
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LogService.reset);

  testWidgets('AI 领出候选为空时兜底出最小单张', (tester) async {
    final game = await aiLandlordTurn(_PassiveAi());
    addTearDown(game.dispose);

    // 叫地主 → AI 领出 → 另一名 AI 不出，多泵几次让定时器全部结算。
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

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

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

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
    game.engine.currentPlayer = 0;
    game.bid(true);
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
}
