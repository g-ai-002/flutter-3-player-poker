import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_3_player_poker/game/card_counter.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/widgets/card_counter_panel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

int total(Map<int, int> counts) =>
    counts.values.fold(0, (sum, count) => sum + count);

void main() {
  test('记牌器扣除自己手牌与已出牌', () {
    final engine = DdzEngine(random: Random(9));
    engine.start();
    engine.players[0].hand
      ..clear()
      ..addAll(handOf('3 3 4 16 17'));
    engine.playedCards.addAll(handOf('3 4 4 5 15'));

    final counts = CardCounter.remaining(engine);

    expect(counts[3], 1); // 4 张 - 自己 2 张 - 已出 1 张
    expect(counts[4], 1); // 4 张 - 自己 1 张 - 已出 2 张
    expect(counts[5], 3);
    expect(counts[15], 3);
    expect(counts[16], 0); // 小王在自己手里
    expect(counts[17], 0); // 大王在自己手里
    expect(total(counts), 54 - 5 - 5);
  });

  test('记牌器不会统计出负数', () {
    final engine = DdzEngine(random: Random(11));
    engine.start();
    engine.players[0].hand
      ..clear()
      ..addAll(handOf('16'));
    engine.playedCards.addAll(handOf('16 16'));

    final counts = CardCounter.remaining(engine);

    expect(counts[16], 0);
    expect(counts[3], 4);
  });

  test('明牌地主的手牌从剩余中扣除', () {
    final engine = DdzEngine(random: Random(13));
    engine.start();
    engine.players[0].hand
      ..clear()
      ..addAll(handOf('3'));
    engine.players[1].hand
      ..clear()
      ..addAll(handOf('4 4'));
    engine.landlord = 1;
    engine.revealed = true;

    expect(CardCounter.remaining(engine)[4], 2);
  });

  test('记牌器牌面标签沿用斗地主叫法', () {
    expect(CardCounter.label(9), '9');
    expect(CardCounter.label(11), 'J');
    expect(CardCounter.label(14), 'A');
    expect(CardCounter.label(15), '2');
    expect(CardCounter.label(16), '小王');
    expect(CardCounter.label(17), '大王');
  });

  testWidgets('记牌器面板只展示还有剩余的牌', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CardCounterPanel(counts: {3: 4, 11: 2, 15: 1, 17: 0}),
        ),
      ),
    );

    expect(find.text('3×4'), findsOneWidget);
    expect(find.text('J×2'), findsOneWidget);
    expect(find.text('2×1'), findsOneWidget);
    expect(find.text('大王×0'), findsNothing);
  });
}
