import '../models/hand_record.dart';
import '../models/playing_card.dart';
import 'game_engine.dart';

/// 牌谱记录器：按动作顺序收集一局内的叫分、加倍、明牌与出牌。
///
/// 只依赖引擎的最终状态生成结算信息，动作文案由 [ActionAnnouncer] 写入，
/// 因此牌谱与界面、日志三处描述始终一致。
class HandRecorder {
  HandRecorder({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _startedAt;
  final List<HandAction> _actions = [];
  final List<List<PlayingCard>> _initialHands = [];

  List<HandAction> get actions => List.unmodifiable(_actions);

  /// 新对局开始时清空上一局记录；传入引擎时保存发牌后的三家手牌。
  void start([DdzEngine? engine]) {
    _startedAt = _clock();
    _actions.clear();
    _initialHands.clear();
    if (engine != null) {
      for (final player in engine.players) {
        _initialHands.add(List.of(player.hand));
      }
    }
  }

  void record(
    int player,
    HandActionType type,
    String text, {
    List<PlayingCard> cards = const [],
    int multiplier = 1,
  }) {
    if (text.isEmpty) return;
    _startedAt ??= _clock();
    _actions.add(
      HandAction(
        player: player,
        type: type,
        text: text,
        cards: List.of(cards),
        multiplier: multiplier,
      ),
    );
  }

  /// 对局结束后生成牌谱；未产生结算结果时返回 null。
  HandRecord? finish(DdzEngine engine, {DateTime? now}) {
    final result = engine.result;
    final start = _startedAt;
    if (result == null || start == null) return null;
    return HandRecord(
      id: start.millisecondsSinceEpoch.toString(),
      startedAt: start,
      endedAt: now ?? _clock(),
      humanIsLandlord: engine.players[0].isLandlord,
      landlordName: engine.players[result.landlord].name,
      landlordWon: result.landlordWon,
      baseScore: engine.baseScore,
      multiplier: result.multiplier,
      spring: result.spring,
      antiSpring: result.antiSpring,
      revealed: engine.revealed,
      scores: List.of(result.scores),
      playerNames: engine.players.map((player) => player.name).toList(),
      bottomCards: List.of(engine.bottomCards),
      actions: List.unmodifiable(_actions),
      initialHands: [for (final hand in _initialHands) List.of(hand)],
    );
  }
}
