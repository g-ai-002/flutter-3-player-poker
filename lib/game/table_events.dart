import '../models/playing_card.dart';

enum TableEventType { deal, play, pass, bid, double, reveal, blast }

/// 牌桌动画事件：由对局逻辑发出，Flame 场景消费。
class TableEvent {
  const TableEvent({
    required this.type,
    this.player = -1,
    this.cards = const [],
    this.text,
  });

  final TableEventType type;
  final int player;
  final List<PlayingCard> cards;
  final String? text;
}

class TableEventBus {
  final List<TableEvent> _pending = [];
  final List<void Function(TableEvent event)> _listeners = [];

  void emit(TableEvent event) {
    for (final listener in List.of(_listeners)) {
      listener(event);
    }
    if (_listeners.isEmpty) {
      _pending.add(event);
      if (_pending.length > 20) _pending.removeAt(0);
    }
  }

  /// Flame 场景加载完成后订阅，并补播加载前的事件。
  void subscribe(void Function(TableEvent event) listener) {
    _listeners.add(listener);
    for (final event in List.of(_pending)) {
      listener(event);
    }
    _pending.clear();
  }

  void unsubscribe(void Function(TableEvent event) listener) {
    _listeners.remove(listener);
  }

  void dispose() => _listeners.clear();
}
