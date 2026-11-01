import 'package:flutter_3_player_poker/models/hand_record.dart';
import 'package:flutter_3_player_poker/services/hand_history_service.dart';
import 'package:flutter_3_player_poker/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

HandRecord makeRecord(int index) {
  final start = DateTime(2026, 11, 1, 10, 0, index);
  return HandRecord(
    id: 'record-$index',
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 5)),
    humanIsLandlord: index.isEven,
    landlordName: '你',
    landlordWon: index.isEven,
    baseScore: 2,
    multiplier: 4,
    spring: false,
    antiSpring: false,
    revealed: false,
    scores: const [8, -4, -4],
    playerNames: const ['你', '小智', '阿福'],
    bottomCards: const [],
    actions: const [
      HandAction(player: 0, type: HandActionType.bid, text: '你 叫 2 分'),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HandHistoryService.instance.resetForTest();
    LogService.reset();
  });

  test('牌谱按时间倒序保留最近 20 局', () async {
    for (var i = 0; i < 25; i++) {
      await HandHistoryService.instance.record(makeRecord(i));
    }

    final records = HandHistoryService.instance.records;
    expect(records, hasLength(HandHistoryService.maxRecords));
    expect(records.first.id, 'record-24');
    expect(records.last.id, 'record-5');
    expect(HandHistoryService.instance.latest?.id, 'record-24');
  });

  test('牌谱持久化后可以重新加载', () async {
    await HandHistoryService.instance.record(makeRecord(1));
    await HandHistoryService.instance.record(makeRecord(2));

    HandHistoryService.instance.resetForTest();
    expect(HandHistoryService.instance.records, isEmpty);

    await HandHistoryService.instance.load();
    expect(HandHistoryService.instance.records, hasLength(2));
    expect(HandHistoryService.instance.records.first.id, 'record-2');
    expect(
      HandHistoryService.instance.records.first.actions.single.text,
      '你 叫 2 分',
    );
  });

  test('清空牌谱后列表为空', () async {
    await HandHistoryService.instance.record(makeRecord(1));
    await HandHistoryService.instance.clear();

    expect(HandHistoryService.instance.records, isEmpty);

    HandHistoryService.instance.resetForTest();
    await HandHistoryService.instance.load();
    expect(HandHistoryService.instance.records, isEmpty);
  });
}
