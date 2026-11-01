import 'dart:math';

import 'package:flutter_3_player_poker/game/ai_player.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('全 AI 对局可以正常结束且没有非法出牌', () {
    var finished = 0;
    for (var seed = 0; seed < 40; seed++) {
      final engine = DdzEngine(random: Random(seed));
      final ai = AiPlayer(random: Random(seed + 500));
      var redeals = 0;

      while (true) {
        engine.start();
        var steps = 0;
        while (engine.phase == GamePhase.bidding && steps < 10) {
          final actor = engine.currentPlayer;
          expect(
            engine.bid(actor, ai.shouldCall(engine.players[actor].hand)),
            isTrue,
          );
          steps++;
        }
        if (engine.phase == GamePhase.redeal) {
          redeals++;
          expect(redeals, lessThan(8), reason: 'seed $seed 反复无人叫地主');
          continue;
        }

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
                  'seed $seed: AI 出牌被拒绝 ${outcome.error.message} '
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
