import 'dart:math';

import 'package:flutter_3_player_poker/game/ai_player.dart';
import 'package:flutter_3_player_poker/game/combo_detector.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/game/hand_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const analyzer = HandAnalyzer();

  group('候选生成', () {
    test('所有候选牌型合法且来自手牌', () {
      final hand = handOf('3 4 5 6 7 8 9 9 10 10 J J Q K A 2 2 16');
      final ids = hand.map((card) => card.id).toSet();
      final options = analyzer.leadCandidates(hand);
      expect(options, isNotEmpty);
      for (final combo in options) {
        expect(detectCombo(combo.cards), isNotNull);
        expect(combo.cards.every((card) => ids.contains(card.id)), isTrue);
        expect(combo.signature, detectCombo(combo.cards)!.signature);
      }
      expect(options.any((combo) => combo.type.name == 'straight'), isTrue);
      expect(options.any((combo) => combo.isBomb), isFalse);
    });

    test('炸弹与王炸会作为候选', () {
      final hand = handOf('7 7 7 7 16 17');
      final options = analyzer.leadCandidates(hand);
      expect(options.any((combo) => combo.type.name == 'bomb'), isTrue);
      expect(options.any((combo) => combo.type.name == 'rocket'), isTrue);
    });

    test('跟牌候选全部能压过目标', () {
      final hand = handOf('3 4 6 8 8 9 9 9 12 12 12 12 16 17');
      final target = detectCombo(handOf('7 7'))!;
      final options = analyzer.beatingCandidates(hand, target);
      expect(options, isNotEmpty);
      for (final combo in options) {
        expect(beatsCombo(combo, target), isTrue);
      }
      expect(
        options.any((combo) => combo.type.name == 'pair' && combo.rank == 8),
        isTrue,
      );
      expect(options.any((combo) => combo.isBomb), isTrue);
    });

    test('飞机带翅膀的提示可被识别', () {
      final hand = handOf('3 3 3 4 4 4 5 6 9 9');
      final options = analyzer.leadCandidates(hand);
      expect(options.any((combo) => combo.type.name == 'planeSingle'), isTrue);
    });

    test('没有可压牌时返回空', () {
      final hand = handOf('3 4 5');
      final target = detectCombo(handOf('2 2'))!;
      expect(analyzer.beatingCandidates(hand, target), isEmpty);
    });
  });

  group('AI 决策', () {
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
      engine.lastCombo = lastRanks == null
          ? null
          : detectCombo(handOf(lastRanks));
      engine.lastPlayer = lastPlayer;
      return engine;
    }

    test('领出时返回合法且属于手牌的牌', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 4 5 6 7 8', 1: '9 9', 2: '10 10'},
      );
      final choice = AiPlayer(random: Random(2)).choose(engine);
      expect(choice, isNotNull);
      final combo = detectCombo(choice!);
      expect(combo, isNotNull);
      final ids = engine.players[0].hand.map((card) => card.id).toSet();
      expect(choice.every((card) => ids.contains(card.id)), isTrue);
    });

    test('农民不压队友', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '4 4', 1: '6 7', 2: '5'},
        current: 1,
        lastRanks: '3',
        lastPlayer: 2,
      );
      engine.players[0].hand
        ..clear()
        ..addAll(handOf('4 4'));
      final choice = AiPlayer(random: Random(1)).choose(engine);
      expect(choice, isNull);
    });

    test('地主跟牌用最小压制', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '4 6 8', 1: '9 9', 2: '10 10'},
        lastRanks: '3',
        lastPlayer: 2,
      );
      final choice = AiPlayer(random: Random(1)).choose(engine);
      expect(choice, isNotNull);
      expect(choice!.length, 1);
      expect(choice.single.rank, 4);
    });

    test('对手即将出完时使用炸弹', () {
      final engine = engineWith(
        landlord: 0,
        hands: {0: '3 3 3 3', 1: '4 5', 2: '2'},
        lastRanks: '2',
        lastPlayer: 2,
      );
      final choice = AiPlayer(random: Random(1)).choose(engine);
      expect(choice, isNotEmpty);
      expect(detectCombo(choice!)!.isBomb, isTrue);
    });

    test('叫地主评分：强牌叫、弱牌不叫', () {
      final strong = handOf('16 17 2 2 2 14 14 13 12 11');
      final weak = handOf('3 4 5 6 7 8 9 10 11 12');
      final ai = AiPlayer(random: Random(3));
      expect(ai.shouldCall(strong), isTrue);
      expect(ai.shouldCall(weak), isFalse);
    });
  });
}
