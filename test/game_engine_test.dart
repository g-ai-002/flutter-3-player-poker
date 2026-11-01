import 'dart:math';

import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

DdzEngine startedEngine({int seed = 7, int landlord = 0}) {
  final engine = DdzEngine(random: Random(seed));
  engine.start();
  engine.currentPlayer = landlord;
  engine.bid(landlord, 1);
  while (engine.phase == GamePhase.bidding) {
    engine.bid(engine.currentPlayer, 0);
  }
  declineDoubling(engine);
  return engine;
}

void setHand(DdzEngine engine, int player, String ranks) {
  engine.players[player].hand
    ..clear()
    ..addAll(handOf(ranks));
}

/// 从玩家真实手牌中取出点数匹配的牌，避免测试用到不在手牌里的对象。
List<PlayingCard> pick(DdzEngine engine, int player, String ranks) {
  final pool = [...engine.players[player].hand];
  final picked = <PlayingCard>[];
  for (final value in ranks.split(' ')) {
    final rank = parseRank(value);
    final index = pool.indexWhere((card) => card.rank == rank);
    expect(index, isNot(-1), reason: '手牌中缺少点数 $rank');
    picked.add(pool.removeAt(index));
  }
  return picked;
}

void main() {
  group('发牌与叫分', () {
    test('54 张牌三人各 17 张，留 3 张底牌', () {
      final engine = DdzEngine(random: Random(3));
      engine.start();
      expect(engine.phase, GamePhase.bidding);
      expect(engine.players.map((p) => p.hand.length), everyElement(17));
      expect(engine.bottomCards.length, 3);
      final ids = <int>{
        for (final player in engine.players)
          for (final card in player.hand) card.id,
        ...engine.bottomCards.map((card) => card.id),
      };
      expect(ids.length, 54);
    });

    test('手牌按点数降序、同点数按 id 稳定排序', () {
      final player = PlayerState(id: 0, name: '你');
      player.hand.addAll([
        const PlayingCard(id: 9, rank: 5, suit: CardSuit.spade),
        const PlayingCard(id: 2, rank: 5, suit: CardSuit.heart),
        const PlayingCard(id: 5, rank: 7, suit: CardSuit.club),
      ]);

      player.sortHand();
      expect(player.hand.map((card) => card.id), [5, 2, 9]);

      final reversed = [...player.hand.reversed];
      player.hand
        ..clear()
        ..addAll(reversed);
      player.sortHand();
      expect(player.hand.map((card) => card.id), [5, 2, 9]);
    });

    test('叫分后收底牌并先出', () {
      final engine = startedEngine(landlord: 2);
      expect(engine.landlord, 2);
      expect(engine.players[2].isLandlord, isTrue);
      expect(engine.players[2].hand.length, 20);
      expect(engine.phase, GamePhase.playing);
      expect(engine.currentPlayer, 2);
      expect(engine.lastCombo, isNull);
    });

    test('叫 3 分立即成为地主，底分与倍数同步', () {
      final engine = DdzEngine(random: Random(4));
      engine.start();
      final landlord = engine.currentPlayer;
      expect(engine.bid(landlord, 3), isTrue);
      expect(engine.landlord, landlord);
      expect(engine.baseScore, 3);
      expect(engine.multiplier, 3);
      expect(engine.phase, GamePhase.doubling);
      expect(engine.lastMoveText, contains('叫 3 分'));
      expect(engine.lastActionText, contains('成为地主'));
    });

    test('叫分必须高于当前最高分', () {
      final engine = DdzEngine(random: Random(6));
      engine.start();
      final first = engine.currentPlayer;
      expect(engine.bid(first, 2), isTrue);
      final second = engine.currentPlayer;
      expect(engine.bid(second, 1), isFalse);
      expect(engine.bid(second, 2), isFalse);
      expect(engine.bid(second, 3), isTrue);
      expect(engine.landlord, second);
      expect(engine.baseScore, 3);
    });

    test('最高分者成为地主，其余玩家叫完后结束', () {
      final engine = DdzEngine(random: Random(8));
      engine.start();
      final first = engine.currentPlayer;
      expect(engine.bid(first, 1), isTrue);
      final second = engine.currentPlayer;
      expect(engine.bid(second, 2), isTrue);
      final third = engine.currentPlayer;
      expect(engine.bid(third, 0), isTrue);
      expect(engine.landlord, second);
      expect(engine.baseScore, 2);
      expect(engine.multiplier, 2);
      expect(engine.phase, GamePhase.doubling);
    });

    test('三家不叫则重新发牌', () {
      final engine = DdzEngine(random: Random(5));
      engine.start();
      while (engine.phase == GamePhase.bidding) {
        expect(engine.bid(engine.currentPlayer, 0), isTrue);
      }
      expect(engine.phase, GamePhase.redeal);
      expect(engine.landlord, isNull);
    });

    test('不是自己的回合不能叫牌', () {
      final engine = DdzEngine(random: Random(9));
      engine.start();
      final other = (engine.currentPlayer + 1) % 3;
      expect(engine.bid(other, 1), isFalse);
      expect(engine.phase, GamePhase.bidding);
    });
  });

  group('加倍', () {
    test('三家依次选择，加倍使倍数翻倍', () {
      final engine = DdzEngine(random: Random(12));
      engine.start();
      final landlord = engine.currentPlayer;
      engine.bid(landlord, 2);
      while (engine.phase == GamePhase.bidding) {
        engine.bid(engine.currentPlayer, 0);
      }
      expect(engine.phase, GamePhase.doubling);
      expect(engine.currentPlayer, landlord);

      expect(engine.doubleUp(landlord, true), isTrue);
      expect(engine.multiplier, 4);
      final farmer = engine.currentPlayer;
      expect(engine.doubleUp(farmer, false), isTrue);
      expect(engine.multiplier, 4);
      expect(engine.doubleUp(engine.currentPlayer, true), isTrue);
      expect(engine.multiplier, 8);
      expect(engine.phase, GamePhase.playing);
      expect(engine.currentPlayer, landlord);
    });

    test('最后一次加倍后仍保留玩家动作文案', () {
      final engine = DdzEngine(random: Random(14));
      engine.start();
      final landlord = engine.currentPlayer;
      engine.bid(landlord, 1);
      while (engine.phase == GamePhase.bidding) {
        engine.bid(engine.currentPlayer, 0);
      }
      while (engine.phase == GamePhase.doubling) {
        engine.doubleUp(engine.currentPlayer, false);
      }

      expect(engine.lastMoveText, endsWith('不加倍'));
      expect(engine.lastActionText, contains('加倍结束'));
    });

    test('未轮到或阶段不符时加倍被拒绝', () {
      final engine = DdzEngine(random: Random(13));
      engine.start();
      final landlord = engine.currentPlayer;
      engine.bid(landlord, 1);
      final other = (landlord + 1) % 3;
      expect(engine.doubleUp(other, true), isFalse);
      declineDoubling(engine);
      expect(engine.doubleUp(landlord, true), isFalse);
    });
  });

  group('明牌', () {
    test('地主明牌使倍数翻倍，且不改变当前回合', () {
      final engine = DdzEngine(random: Random(21));
      engine.start();
      final landlord = engine.currentPlayer;
      engine.bid(landlord, 2);
      while (engine.phase == GamePhase.bidding) {
        engine.bid(engine.currentPlayer, 0);
      }

      expect(engine.revealed, isFalse);
      expect(engine.revealHand(landlord), isTrue);
      expect(engine.revealed, isTrue);
      expect(engine.multiplier, 4);
      expect(engine.currentPlayer, landlord);
      expect(engine.phase, GamePhase.doubling);
      expect(engine.lastActionText, contains('明牌'));

      expect(engine.doubleUp(landlord, true), isTrue);
      expect(engine.multiplier, 8);
    });

    test('只有地主能明牌，且每局仅一次', () {
      final engine = DdzEngine(random: Random(22));
      engine.start();
      final landlord = engine.currentPlayer;
      engine.bid(landlord, 1);
      while (engine.phase == GamePhase.bidding) {
        engine.bid(engine.currentPlayer, 0);
      }
      final farmer = (landlord + 1) % 3;

      expect(engine.revealHand(farmer), isFalse);
      expect(engine.revealHand(landlord), isTrue);
      expect(engine.revealHand(landlord), isFalse);
      expect(engine.multiplier, 2);
    });

    test('非加倍阶段不能明牌，重新开始后状态复位', () {
      final engine = startedEngine();
      expect(engine.phase, GamePhase.playing);
      expect(engine.revealHand(0), isFalse);

      final fresh = DdzEngine(random: Random(23));
      fresh.start();
      fresh.currentPlayer = 0;
      fresh.bid(0, 3);
      expect(fresh.revealHand(0), isTrue);
      expect(fresh.revealed, isTrue);

      fresh.start();
      expect(fresh.revealed, isFalse);
    });
  });

  group('出牌流程', () {
    test('出牌后轮转到下家，非法牌型被拒绝', () {
      final engine = startedEngine();
      setHand(engine, 0, '3 3 4 5');
      setHand(engine, 1, '4 5 6');
      setHand(engine, 2, '7 8 9');
      engine.currentPlayer = 0;

      final invalid = engine.play(0, pick(engine, 0, '3 3 4'));
      expect(invalid.error, PlayError.invalidCombo);
      expect(engine.players[0].hand.length, 4);

      final ok = engine.play(0, [engine.players[0].hand.first]);
      expect(ok.ok, isTrue);
      expect(engine.currentPlayer, 1);
      expect(engine.players[0].hand.length, 3);
    });

    test('不能压过时拒绝出牌', () {
      final engine = startedEngine();
      setHand(engine, 0, '5 5 9');
      setHand(engine, 1, '4 4 6');
      engine.currentPlayer = 0;

      expect(engine.play(0, pick(engine, 0, '5 5')).ok, isTrue);
      final outcome = engine.play(1, pick(engine, 1, '4 4'));
      expect(outcome.error, PlayError.cannotBeat);
      expect(engine.currentPlayer, 1);
    });

    test('领出时不能不出', () {
      final engine = startedEngine();
      setHand(engine, 0, '3 4');
      engine.currentPlayer = 0;
      expect(engine.pass(0), PlayError.mustPlay);
    });

    test('两家不出后由最后出牌者重新领出', () {
      final engine = startedEngine();
      setHand(engine, 0, '3 4 5');
      setHand(engine, 1, '6 7 8');
      setHand(engine, 2, '9 10 11');
      engine.currentPlayer = 0;

      expect(engine.play(0, pick(engine, 0, '3')).ok, isTrue);
      expect(engine.pass(1), PlayError.none);
      expect(engine.pass(2), PlayError.none);
      expect(engine.currentPlayer, 0);
      expect(engine.lastCombo, isNull);
      expect(engine.lastPlayer, -1);
      expect(engine.players[0].lastPlay, isEmpty);
      expect(engine.lastMoveText, '阿福 不出');
      expect(engine.lastActionText, contains('重新领出'));
    });

    test('炸弹翻倍', () {
      final engine = startedEngine();
      setHand(engine, 0, '3 3 3 3 9');
      engine.currentPlayer = 0;
      expect(engine.play(0, pick(engine, 0, '3 3 3 3')).ok, isTrue);
      expect(engine.multiplier, 2);
      expect(engine.currentPlayer, 1);
    });

    test('手牌校验：不能出不属于自己的牌', () {
      final engine = startedEngine();
      setHand(engine, 0, '3 4 5');
      engine.currentPlayer = 0;
      final foreign = card(6);
      expect(engine.play(0, [foreign]).error, PlayError.cardsNotInHand);
    });

    test('王炸翻倍但不结束对局', () {
      final engine = startedEngine();
      setHand(engine, 0, '9 16 17');
      engine.currentPlayer = 0;
      expect(engine.play(0, pick(engine, 0, '16 17')).ok, isTrue);
      expect(engine.multiplier, 2);
      expect(engine.phase, GamePhase.playing);
      expect(engine.currentPlayer, 1);
      expect(engine.players[0].hand.length, 1);
    });

    test('不是自己的回合无法出牌或不出', () {
      final engine = startedEngine();
      setHand(engine, 0, '3 4');
      engine.currentPlayer = 1;
      expect(
        engine.play(0, [engine.players[0].hand.first]).error,
        PlayError.notYourTurn,
      );
      expect(engine.pass(0), PlayError.notYourTurn);
    });

    test('重新开始会重置手牌、倍数与底牌', () {
      final engine = startedEngine();
      setHand(engine, 0, '3 3 3 3 9');
      engine.currentPlayer = 0;
      engine.play(0, pick(engine, 0, '3 3 3 3'));
      expect(engine.multiplier, 2);

      engine.start();
      expect(engine.phase, GamePhase.bidding);
      expect(engine.players.map((p) => p.hand.length), everyElement(17));
      expect(engine.bottomCards.length, 3);
      expect(engine.multiplier, 1);
      expect(engine.landlord, isNull);
      expect(engine.lastCombo, isNull);
    });
  });

  group('结算', () {
    test('地主出完牌获胜，农民各扣一分', () {
      final engine = startedEngine();
      setHand(engine, 0, '3');
      setHand(engine, 1, '4 5');
      setHand(engine, 2, '6 7');
      engine.players[1].playCount = 1;
      engine.players[2].playCount = 1;
      engine.currentPlayer = 0;

      expect(engine.play(0, pick(engine, 0, '3')).ok, isTrue);
      expect(engine.phase, GamePhase.finished);
      final result = engine.result!;
      expect(result.landlordWon, isTrue);
      expect(result.spring, isFalse);
      expect(result.multiplier, 1);
      expect(result.scores, [2, -1, -1]);
    });

    test('地主一手走完触发春天', () {
      final engine = startedEngine();
      setHand(engine, 0, '3');
      setHand(engine, 1, '4 5');
      setHand(engine, 2, '6 7');
      engine.currentPlayer = 0;
      engine.play(0, pick(engine, 0, '3'));
      final result = engine.result!;
      expect(result.spring, isTrue);
      expect(result.multiplier, 2);
      expect(result.scores, [4, -2, -2]);
    });

    test('农民获胜且地主只出过一手，触发反春天', () {
      final engine = startedEngine();
      setHand(engine, 0, '5 6');
      setHand(engine, 1, '2');
      setHand(engine, 2, '7 8');
      engine.currentPlayer = 0;

      expect(engine.play(0, pick(engine, 0, '5')).ok, isTrue);
      expect(engine.play(1, pick(engine, 1, '2')).ok, isTrue);
      expect(engine.phase, GamePhase.finished);
      final result = engine.result!;
      expect(result.landlordWon, isFalse);
      expect(result.antiSpring, isTrue);
      expect(result.multiplier, 2);
      expect(result.scores, [-4, 2, 2]);
    });
  });
}
