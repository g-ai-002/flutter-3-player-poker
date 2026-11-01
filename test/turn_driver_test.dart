import 'dart:math';

import 'package:flutter_3_player_poker/game/action_announcer.dart';
import 'package:flutter_3_player_poker/game/ai_player.dart';
import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/game/table_events.dart';
import 'package:flutter_3_player_poker/game/turn_driver.dart';
import 'package:flutter_3_player_poker/models/app_settings.dart';
import 'package:flutter_3_player_poker/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 叫分返回非法分数，模拟 AI 评分逻辑异常。
class _InvalidBidAi extends AiPlayer {
  @override
  int bidScore(DdzEngine engine) => 9;
}

/// 只在玩家 1 回合想加倍，用于验证加倍被拒绝后的降级。
class _EagerDoubleAi extends AiPlayer {
  @override
  bool shouldDouble(DdzEngine engine) => engine.currentPlayer == 1;
}

/// 地主回合先明牌再选择不加倍。
class _RevealAi extends AiPlayer {
  @override
  bool shouldReveal(DdzEngine engine) => true;

  @override
  bool shouldDouble(DdzEngine engine) => false;
}

/// 只拒绝 AI（玩家 1）的第一次加倍，其余正常放行。
class _RejectAiDoubleEngine extends DdzEngine {
  _RejectAiDoubleEngine({super.random});

  bool _rejected = false;

  @override
  bool doubleUp(int playerId, bool doubled) {
    if (playerId == 1 && !_rejected) {
      _rejected = true;
      return false;
    }
    return super.doubleUp(playerId, doubled);
  }
}

/// 所有叫分都被拒绝，模拟引擎状态异常。
class _RejectAllBidsEngine extends DdzEngine {
  _RejectAllBidsEngine({super.random});

  @override
  bool bid(int playerId, int score) => false;
}

TurnDriver makeDriver(
  DdzEngine engine, {
  AiPlayer? ai,
  void Function(String message)? onFeedback,
}) {
  final announcer = ActionAnnouncer(engine: engine, events: TableEventBus());
  return TurnDriver(
    engine: engine,
    ai: ai ?? AiPlayer(),
    announcer: announcer,
    level: () => AiLevel.normal,
    speedDelayMs: () => 0,
    onChanged: () {},
    onFeedback: onFeedback ?? (_) {},
    onRedeal: () {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LogService.reset);

  testWidgets('AI 叫分被拒绝时降级为不叫并继续轮转', (tester) async {
    final engine = DdzEngine(random: Random(1));
    engine.start();
    engine.currentPlayer = 1;
    final driver = makeDriver(engine, ai: _InvalidBidAi());
    addTearDown(driver.dispose);

    driver.schedule();
    await tester.pump(const Duration(milliseconds: 1));

    expect(engine.bids[1], 0);
    expect(
      LogService.getRecentLogs().any((line) => line.contains('降级为不叫')),
      isTrue,
    );
  });

  testWidgets('AI 加倍被拒绝时降级为不加倍并推进', (tester) async {
    final engine = _RejectAiDoubleEngine(random: Random(2));
    engine.start();
    engine.currentPlayer = 0;
    engine.bid(0, 3);
    engine.doubleUp(0, false);
    expect(engine.currentPlayer, 1);
    final driver = makeDriver(engine, ai: _EagerDoubleAi());
    addTearDown(driver.dispose);

    driver.schedule();
    await tester.pump(const Duration(milliseconds: 1));

    expect(engine.multiplier, 3);
    expect(engine.doublingIndex, greaterThanOrEqualTo(2));
    expect(
      LogService.getRecentLogs().any((line) => line.contains('降级为不加倍')),
      isTrue,
    );
  });

  testWidgets('AI 地主在加倍前明牌并继续推进', (tester) async {
    final engine = DdzEngine(random: Random(4));
    engine.start();
    engine.currentPlayer = 1;
    expect(engine.bid(1, 3), isTrue);
    expect(engine.phase, GamePhase.doubling);
    final driver = makeDriver(engine, ai: _RevealAi());
    addTearDown(driver.dispose);

    driver.schedule();
    await tester.pump(const Duration(milliseconds: 1));

    expect(engine.revealed, isTrue);
    expect(engine.multiplier, 6);
    expect(engine.currentPlayer, 0);
    expect(
      LogService.getRecentLogs().any((line) => line.contains('明牌')),
      isTrue,
    );
  });

  testWidgets('AI 叫分连续被拒绝时提示重开而不是空转', (tester) async {
    final engine = _RejectAllBidsEngine(random: Random(3));
    engine.start();
    engine.currentPlayer = 1;
    String? feedback;
    final driver = makeDriver(
      engine,
      ai: _InvalidBidAi(),
      onFeedback: (message) => feedback = message,
    );
    addTearDown(driver.dispose);

    driver.schedule();
    await tester.pump(const Duration(milliseconds: 1));

    expect(feedback, contains('AI 叫分异常'));
    expect(driver.thinkingPlayer, isNull);
    expect(
      LogService.getRecentLogs().any((line) => line.contains('AI 叫分异常')),
      isTrue,
    );
  });
}
