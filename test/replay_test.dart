import 'package:flutter/material.dart';
import 'package:flutter_3_player_poker/game/replay.dart';
import 'package:flutter_3_player_poker/models/hand_record.dart';
import 'package:flutter_3_player_poker/pages/replay_page.dart';
import 'package:flutter_3_player_poker/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

HandRecord demoRecord({bool withHands = true, bool legacy = false}) {
  final three = card(3);
  final eight = card(8);
  final ten = card(10);
  final four = card(4);
  return HandRecord(
    id: 'replay',
    startedAt: DateTime(2026, 11, 2, 10),
    endedAt: DateTime(2026, 11, 2, 10, 5),
    humanIsLandlord: true,
    landlordName: '你',
    landlordWon: true,
    baseScore: 2,
    multiplier: 4,
    spring: false,
    antiSpring: false,
    revealed: false,
    scores: const [4, -2, -2],
    playerNames: const ['你', '小智', '阿福'],
    bottomCards: [ten],
    initialHands: withHands
        ? [
            [three, eight],
            [four],
            const [],
          ]
        : const [],
    actions: [
      HandAction(
        player: 0,
        type: HandActionType.bid,
        text: '你 叫 2 分',
        multiplier: legacy ? 1 : 2,
      ),
      HandAction(
        player: 1,
        type: HandActionType.double,
        text: '小智 加倍，倍数 ×4',
        multiplier: legacy ? 1 : 4,
      ),
      HandAction(
        player: 0,
        type: HandActionType.play,
        text: '你 打出单张 8',
        cards: [eight],
        multiplier: legacy ? 1 : 4,
      ),
    ],
  );
}

void main() {
  test('复盘逐手还原手牌、底牌与倍数', () {
    final record = demoRecord();
    final steps = buildReplay(record);
    final eight = record.actions.last.cards.single;

    expect(steps, hasLength(5));
    expect(steps.first.title, '开局手牌');
    expect(steps.first.hands[0], hasLength(2));
    expect(steps[1].hands[0], hasLength(3));
    expect(steps[1].hands[0].first.rank, 10);
    expect(steps[1].multiplier, 2);
    expect(steps[2].multiplier, 4);
    expect(steps[3].hands[0].map((card) => card.id), isNot(contains(eight.id)));
    expect(steps[3].hands[0], hasLength(2));
    expect(steps.last.title, '地主获胜 · 倍数 ×4');
    expect(steps.last.multiplier, 4);
  });

  test('旧牌谱没有开局手牌时仍可回放动作与倍数', () {
    final steps = buildReplay(demoRecord(withHands: false, legacy: true));

    expect(steps.first.hands.every((hand) => hand.isEmpty), isTrue);
    expect(steps.map((step) => step.multiplier), [1, 2, 4, 4, 4]);
    expect(steps[1].title, '你 叫 2 分');
  });

  testWidgets('复盘页可逐步查看手牌与倍数', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: ReplayPage(record: demoRecord()),
      ),
    );
    await tester.pump();

    expect(find.text('对局复盘'), findsOneWidget);
    expect(find.text('开局手牌'), findsOneWidget);
    expect(find.text('倍数 ×1'), findsOneWidget);
    expect(find.text('2 张'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pump();
    expect(find.text('你 叫 2 分'), findsOneWidget);
    expect(find.text('倍数 ×2'), findsOneWidget);
    expect(find.text('3 张'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pump();
    expect(find.text('小智 加倍，倍数 ×4'), findsOneWidget);
    expect(find.text('倍数 ×4'), findsOneWidget);
  });
}
