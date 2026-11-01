import 'dart:math';

import 'package:flutter_3_player_poker/game/ai_player.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  for (final level in AiLevel.values) {
    test('${level.label} AI 对局可以正常结束且没有非法出牌', () {
      var finished = 0;
      for (var seed = 0; seed < 40; seed++) {
        final engine = DdzEngine(random: Random(seed));
        final ai = AiPlayer(random: Random(seed + 500), level: level);
        var redeals = 0;

        while (true) {
          engine.start();
          var steps = 0;
          while (engine.phase == GamePhase.bidding && steps < 10) {
            final actor = engine.currentPlayer;
            expect(engine.bid(actor, ai.bidScore(engine)), isTrue);
            steps++;
          }
          if (engine.phase == GamePhase.redeal) {
            redeals++;
            expect(redeals, lessThan(8), reason: 'seed $seed 反复无人叫地主');
            continue;
          }

          var doubles = 0;
          while (engine.phase == GamePhase.doubling && doubles < 5) {
            final actor = engine.currentPlayer;
            expect(engine.doubleUp(actor, ai.shouldDouble(engine)), isTrue);
            doubles++;
          }
          expect(engine.phase, GamePhase.playing, reason: 'seed $seed 加倍未结束');

          var turns = 0;
          while (engine.phase == GamePhase.playing && turns < 600) {
            final actor = engine.currentPlayer;
            final choice = ai.choose(engine);
            if (choice == null) {
              expect(engine.lastCombo, isNotNull, reason: '领出时 AI 不应不出');
              expect(engine.pass(actor), PlayError.none);
            } else {
              final outcome = engine.play(actor, choice);
              expect(
                outcome.ok,
                isTrue,
                reason:
                    'seed $seed ${level.label}: '
                    'AI 出牌被拒绝 ${outcome.error.message} '
                    '${choice.map((c) => c.displayName).join(' ')}',
              );
            }
            turns++;
          }
          expect(engine.phase, GamePhase.finished, reason: 'seed $seed 对局未结束');
          expect(engine.result, isNotNull);
          finished++;
          break;
        }
      }
      expect(finished, 40);
    });
  }

  test('高手 AI 记牌后不会打出不存在的牌', () {
    final engine = DdzEngine(random: Random(21));
    final ai = AiPlayer(random: Random(22), level: AiLevel.hard);
    engine.start();
    while (engine.phase == GamePhase.bidding) {
      final actor = engine.currentPlayer;
      engine.bid(actor, ai.bidScore(engine));
    }
    declineDoubling(engine);
    final handIds = engine.current.hand.map((card) => card.id).toSet();
    final choice = ai.choose(engine);
    expect(choice, isNotNull);
    expect(choice!.every((card) => handIds.contains(card.id)), isTrue);
  });
}
