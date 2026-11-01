import '../models/hand_record.dart';
import '../services/log_service.dart';
import 'combo.dart';
import 'game_engine.dart';
import 'hand_recorder.dart';
import 'table_events.dart';

/// 动作广播：把引擎产生的动作统一转成牌桌事件、日志与牌谱。
///
/// 日志与牌谱取 [DdzEngine.lastMoveText]（玩家实际动作）；牌桌提示仍取
/// [DdzEngine.lastActionText]，因此“加倍结束”“两家不出”等阶段文案不会
/// 覆盖牌谱里的“不加倍”“不出”。
class ActionAnnouncer {
  ActionAnnouncer({required this.engine, required this.events, this.recorder});

  final DdzEngine engine;
  final TableEventBus events;
  final HandRecorder? recorder;

  void bid(int playerId) {
    _emitWithText(TableEventType.bid, playerId, HandActionType.bid);
  }

  void doubleUp(int playerId) {
    _emitWithText(TableEventType.double, playerId, HandActionType.double);
  }

  void reveal(int playerId) {
    _emitWithText(TableEventType.reveal, playerId, HandActionType.reveal);
  }

  void pass(int playerId) {
    _emitWithText(TableEventType.pass, playerId, HandActionType.pass);
  }

  void play(int playerId, Combo? combo, {String? text}) {
    if (combo == null) return;
    events.emit(
      TableEvent(
        type: TableEventType.play,
        player: playerId,
        cards: combo.cards,
      ),
    );
    if (combo.isBomb) {
      events.emit(
        TableEvent(
          type: TableEventType.blast,
          player: playerId,
          text: combo.description,
        ),
      );
    }
    final actionText =
        text ??
        engine.lastMoveText ??
        '${engine.players[playerId].name} 打出${combo.description}';
    recorder?.record(
      playerId,
      HandActionType.play,
      actionText,
      cards: combo.cards,
      multiplier: engine.multiplier,
    );
    LogService.info(
      '$actionText '
      '[${combo.cards.map((card) => card.displayName).join(' ')}], '
      '剩余 ${engine.players[playerId].hand.length} 张',
    );
  }

  void _emitWithText(TableEventType type, int playerId, HandActionType action) {
    final text = engine.lastMoveText;
    events.emit(TableEvent(type: type, player: playerId, text: text));
    if (text != null && text.isNotEmpty) {
      LogService.info(text);
      recorder?.record(playerId, action, text, multiplier: engine.multiplier);
    }
  }
}
