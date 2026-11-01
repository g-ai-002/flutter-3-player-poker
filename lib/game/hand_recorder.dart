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

  DateTime? get startedAt => _startedAt;

  List<HandAction> get actions => List.unmodifiable(_actions);

  /// 新对局开始时清空上一局记录。
  void start() {
    _startedAt = _clock();
    _actions.clear();
  }

  void record(
    int player,
    HandActionType type,
    String text, {
    List<PlayingCard> cards = const [],
  }) {
    if (text.isEmpty) return;
    _startedAt ??= _clock();
    _actions.add(
      HandAction(player: player, type: type, text: text, cards: List.of(cards)),
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
    );
  }
}
