import 'package:flutter_3_player_poker/game/game_engine.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';

int _nextId = 0;

PlayingCard card(int rank, {CardSuit? suit}) {
  return PlayingCard(
    id: _nextId++,
    rank: rank,
    suit: suit ?? (rank >= 16 ? CardSuit.joker : CardSuit.spade),
  );
}

List<PlayingCard> cards(List<int> ranks) => ranks.map(card).toList();

/// 支持 2 / J / Q / K / A 与 16（小王）/ 17（大王）。
int parseRank(String value) {
  return switch (value.toUpperCase()) {
    'J' => 11,
    'Q' => 12,
    'K' => 13,
    'A' => 14,
    '2' => 15,
    _ => int.parse(value),
  };
}

/// 把 "3 3 3 4" 这样的点数序列转成牌。
List<PlayingCard> handOf(String ranks) {
  return cards(
    ranks.split(' ').where((value) => value.isNotEmpty).map(parseRank).toList(),
  );
}

/// 叫分后依次让三方选择不加倍，把引擎推进到出牌阶段。
void declineDoubling(DdzEngine engine) {
  var guard = 0;
  while (engine.phase == GamePhase.doubling && guard++ < 3) {
    engine.doubleUp(engine.currentPlayer, false);
  }
}
