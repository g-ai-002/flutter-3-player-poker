import 'dart:math';

import 'package:flutter_3_player_poker/game/ai_player.dart';
import 'package:flutter_3_player_poker/game/combo_detector.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

DdzEngine engineWith({
  required int landlord,
  required Map<int, String> hands,
  int current = 0,
  String? lastRanks,
  int lastPlayer = -1,
}) {
  final engine = DdzEngine(random: Random(11));
  engine.start();
  engine.currentPlayer = landlord;
  engine.bid(landlord, 1);
  while (engine.phase == GamePhase.bidding) {
    engine.bid(engine.currentPlayer, 0);
  }
  declineDoubling(engine);
  hands.forEach((player, ranks) {
    engine.players[player].hand
      ..clear()
      ..addAll(handOf(ranks));
  });
  engine.currentPlayer = current;
  engine.lastCombo = lastRanks == null ? null : detectCombo(handOf(lastRanks));
  engine.lastPlayer = lastPlayer;
  return engine;
}

void main() {
  group('AI 领出策略', () {
    test('不拆炸弹：带炸弹时领出不用炸弹中的牌', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 3 3 3 4 5 6 7 8 9', 1: '2 2', 2: 'K K'},
      );
      final choice = AiPlayer(random: Random(2)).choose(engine)!;
      expect(choice.any((card) => card.rank == 3), isFalse);
      expect(detectCombo(choice), isNotNull);
    });

    test('不拆王炸：持有大小王时领出不拆开', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '4 5 6 7 8 16 17', 1: '9 9', 2: '10 10'},
      );
      final choice = AiPlayer(random: Random(2)).choose(engine)!;
      expect(choice.any((card) => card.isJoker), isFalse);
    });

    test('对手只剩一张时优先出多张牌型', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: 'K', 1: '3 5 5 9 9', 2: '6 7'},
        current: 1,
      );
      final choice = AiPlayer(random: Random(2)).choose(engine)!;
      expect(choice.length, greaterThan(1));
      expect(detectCombo(choice)!.type.name, contains('pair'));
    });

    test('对手只剩一张但自己只剩单张时仍然出牌', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: 'K', 1: '3', 2: '6 7'},
        current: 1,
      );
      final choice = AiPlayer(random: Random(2)).choose(engine);
      expect(choice, isNotNull);
      expect(choice!.single.rank, 3);
    });
  });

  group('AI 跟牌策略', () {
    test('不为压小牌拆掉炸弹', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 3 3 3 7 9', 1: '8 8', 2: '5 6 10 10 10'},
        lastRanks: '6',
        lastPlayer: 2,
      );
      final choice = AiPlayer(random: Random(2)).choose(engine)!;
      expect(choice.single.rank, 7);
    });

    test('对手即将出完时允许拆炸弹拦截', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 3 3 3 9', 1: '8 8', 2: '5 6 10 10 10'},
        lastRanks: '8',
        lastPlayer: 2,
      );
      final choice = AiPlayer(random: Random(2)).choose(engine);
      expect(choice, isNotNull);
      expect(choice!.single.rank, 9);
    });

    test('提示同样不会拆王炸', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '4 5 6 7 8 16 17', 1: '9 9', 2: '10 10'},
      );
      final hint = AiPlayer(random: Random(2)).hintAdvice(engine).cards!;
      expect(hint.any((card) => card.isJoker), isFalse);
    });

    test('跟牌提示不拆炸弹，有替代单张时优先替代牌', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 3 3 3 7 9', 1: '8 8', 2: '5 6 10 10 10'},
        lastRanks: '6',
        lastPlayer: 2,
      );
      final hint = AiPlayer(random: Random(2)).hintAdvice(engine).cards!;
      expect(hint.single.rank, 7);
    });

    test('没有替代牌时提示炸弹', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 3 3 3', 1: '8 8', 2: '5 6 10 10 10'},
        lastRanks: '5',
        lastPlayer: 2,
      );
      final hint = AiPlayer(random: Random(2)).hintAdvice(engine).cards!;
      expect(hint.length, 4);
      expect(detectCombo(hint)!.type.name, 'bomb');
    });

    test('跟牌提示附带最小压制的理由', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '7 9', 1: '8 8', 2: '5 6 10 10 10'},
        lastRanks: '6',
        lastPlayer: 2,
      );
      final advice = AiPlayer(random: Random(2)).hintAdvice(engine);
      expect(advice.cards, isNotEmpty);
      expect(advice.reason, contains('压过'));
    });

    test('领出提示说明剩余手数', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 4 5 6 7 9 9', 1: '8 8', 2: '5 6 10 10 10'},
      );
      final advice = AiPlayer(random: Random(2)).hintAdvice(engine);
      expect(advice.cards, isNotEmpty);
      expect(advice.reason, anyOf(contains('还剩'), contains('一手走完')));
    });

    test('无牌可压时提示不出并说明原因', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 4', 1: '8 8', 2: '2'},
        lastRanks: '2',
        lastPlayer: 2,
      );
      final advice = AiPlayer(random: Random(2)).hintAdvice(engine);
      expect(advice.cards, isNull);
      expect(advice.reason, contains('建议不出'));
    });
  });

  group('AI 控制牌与残局', () {
    test('局势不紧张时不为对手的小牌交出唯一的 2', () {
      final engine = engineWith(
        landlord: 1,
        hands: {
          0: '2 3 4 5 6 7 8 9',
          1: '3 4 5 6 7 8 9 10',
          2: '3 4 5 6 7 8 9 10',
        },
        lastRanks: '10',
        lastPlayer: 1,
      );
      final choice = AiPlayer(random: Random(2)).choose(engine);
      expect(choice, isNull);
    });

    test('还有别的控制牌时正常跟牌', () {
      final engine = engineWith(
        landlord: 1,
        hands: {
          0: '2 2 3 4 5 6 7 8',
          1: '3 4 5 6 7 8 9 10',
          2: '3 4 5 6 7 8 9 10',
        },
        lastRanks: '10',
        lastPlayer: 1,
      );
      final choice = AiPlayer(random: Random(2)).choose(engine);
      expect(choice, isNotNull);
      expect(choice!.single.rank, 15);
    });

    test('对手只剩一张时领出最大的多张牌型', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 9 9 K K', 1: '4', 2: '5 5 5 5 6 6'},
      );
      final choice = AiPlayer(random: Random(2)).choose(engine)!;
      expect(choice.length, greaterThan(1));
      final combo = detectCombo(choice)!;
      expect(combo.type.name, contains('pair'));
      expect(combo.rank, 13);
    });
  });

  group('AI 明牌策略', () {
    DdzEngine doublingEngine({required int landlord}) {
      final engine = DdzEngine(random: Random(41));
      engine.start();
      engine.currentPlayer = landlord;
      expect(engine.bid(landlord, 1), isTrue);
      while (engine.phase == GamePhase.bidding) {
        engine.bid(engine.currentPlayer, 0);
      }
      return engine;
    }

    test('高手地主手牌足够强时明牌，普通难度不明牌', () {
      final engine = doublingEngine(landlord: 0);
      engine.players[0].hand
        ..clear()
        ..addAll(handOf('17 16 15 15 15 15 14 14 14 14'));

      final ai = AiPlayer(random: Random(3), level: AiLevel.hard);
      expect(ai.shouldReveal(engine), isTrue);

      ai.level = AiLevel.normal;
      expect(ai.shouldReveal(engine), isFalse);
    });

    test('牌力不足或不是地主时不明牌', () {
      final engine = doublingEngine(landlord: 0);
      engine.players[0].hand
        ..clear()
        ..addAll(handOf('3 4 5 6 7 8 9 10'));

      final ai = AiPlayer(random: Random(3), level: AiLevel.hard);
      expect(ai.shouldReveal(engine), isFalse);

      engine.players[0].hand
        ..clear()
        ..addAll(handOf('17 16 15 15 15 15 14 14 14 14'));
      engine.currentPlayer = 1;
      expect(ai.shouldReveal(engine), isFalse);
    });
  });
}
