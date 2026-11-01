import 'dart:math';

import 'package:flutter_3_player_poker/game/ai_player.dart';
import 'package:flutter_3_player_poker/game/combo_detector.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
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
  engine.bid(landlord, true);
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
      final hint = AiPlayer(random: Random(2)).hint(engine)!;
      expect(hint.any((card) => card.isJoker), isFalse);
    });
  });
}
