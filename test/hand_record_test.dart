import 'dart:convert';
import 'dart:math';

import 'package:flutter_3_player_poker/game/action_announcer.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/game/hand_recorder.dart';
import 'package:flutter_3_player_poker/game/table_events.dart';
import 'package:flutter_3_player_poker/models/hand_record.dart';
import 'package:flutter_3_player_poker/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

HandRecord buildRecord({DateTime? now}) {
  final engine = DdzEngine(random: Random(31));
  engine.start();
  engine.currentPlayer = 0;
  DateTime clock() => DateTime(2026, 11, 1, 20, 30, 12);
  final recorder = HandRecorder(clock: clock);
  final announcer = ActionAnnouncer(
    engine: engine,
    events: TableEventBus(),
    recorder: recorder,
  );

  recorder.start();
  expect(engine.bid(0, 3), isTrue);
  announcer.bid(0);
  expect(engine.revealHand(0), isTrue);
  announcer.reveal(0);
  while (engine.phase == GamePhase.doubling) {
    final actor = engine.currentPlayer;
    expect(engine.doubleUp(actor, false), isTrue);
    announcer.doubleUp(actor);
  }

  engine.players[0].hand
    ..clear()
    ..addAll(handOf('3'));
  engine.players[1].hand
    ..clear()
    ..addAll(handOf('4 5'));
  engine.players[2].hand
    ..clear()
    ..addAll(handOf('6 7'));
  engine.currentPlayer = 0;

  final outcome = engine.play(0, engine.players[0].hand.toList());
  expect(outcome.ok, isTrue);
  announcer.play(0, outcome.combo, text: outcome.text);

  final record = recorder.finish(engine, now: now ?? clock());
  expect(record, isNotNull);
  return record!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LogService.reset);

  test('牌谱记录叫分、明牌、加倍与出牌', () {
    final record = buildRecord();

    expect(record.humanIsLandlord, isTrue);
    expect(record.landlordWon, isTrue);
    expect(record.spring, isTrue);
    expect(record.revealed, isTrue);
    expect(record.baseScore, 3);
    expect(record.multiplier, 12);
    expect(record.scores, [24, -12, -12]);
    expect(record.humanScore, 24);
    expect(record.humanWon, isTrue);
    expect(record.actions.first.type, HandActionType.bid);
    expect(record.actions[1].type, HandActionType.reveal);
    expect(
      record.actions.where((action) => action.type == HandActionType.double),
      hasLength(3),
    );
    final play = record.actions.last;
    expect(play.type, HandActionType.play);
    expect(play.cards.single.rank, 3);
  });

  test('牌谱 JSON 往返保留结算、底牌与动作', () {
    final record = buildRecord();
    final restored = HandRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );

    expect(restored.id, record.id);
    expect(restored.startedAt, record.startedAt);
    expect(restored.humanIsLandlord, record.humanIsLandlord);
    expect(restored.multiplier, record.multiplier);
    expect(restored.revealed, isTrue);
    expect(restored.scores, record.scores);
    expect(restored.actions.length, record.actions.length);
    expect(restored.bottomCards.length, record.bottomCards.length);
    expect(
      restored.actions.last.cards.single.id,
      record.actions.last.cards.single.id,
    );
  });

  test('牌谱文本包含结果、明牌与逐步记录', () {
    final text = buildRecord().toText();

    expect(text, contains('斗地主 · 牌谱'));
    expect(text, contains('身份: 地主'));
    expect(text, contains('地主获胜 · 春天 · 倍数 ×12'));
    expect(text, contains('明牌: 地主已亮牌'));
    expect(text, contains('1. 你 以 3 分成为地主'));
    expect(text, contains('出牌记录'));
  });

  test('非法 JSON 字段回落到安全默认值', () {
    final record = HandRecord.fromJson(const {
      'id': 1,
      'scores': ['x', 2],
      'actions': [
        {'player': 'a', 'type': 'unknown', 'text': 1},
      ],
    });

    expect(record.id, '');
    expect(record.scores, [0, 2]);
    expect(record.actions.single.type, HandActionType.play);
    expect(record.actions.single.text, '');
  });
}
