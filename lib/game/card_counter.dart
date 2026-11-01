import '../models/playing_card.dart';
import 'game_engine.dart';

/// 记牌器：统计自己手牌与已出牌之外，两名对手还剩哪些牌。
///
/// 只做只读统计，不参与出牌校验；地主明牌后，其手牌已是公开信息，
/// 也会从剩余中扣除，面板始终表示“尚未见过的牌”。
class CardCounter {
  CardCounter._();

  /// 展示顺序：3 → 2 → 小王 → 大王。
  static const List<int> ranks = [
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
  ];

  static String label(int rank) => PlayingCard.rankName(rank);

  /// 点数 -> 两家对手剩余张数。
  static Map<int, int> remaining(DdzEngine engine, {int player = 0}) {
    final counts = Map<int, int>.of(PlayingCard.rankTotals);
    void take(PlayingCard card) {
      final left = (counts[card.rank] ?? 0) - 1;
      counts[card.rank] = left < 0 ? 0 : left;
    }

    engine.players[player].hand.forEach(take);
    engine.playedCards.forEach(take);
    final landlord = engine.landlord;
    if (engine.revealed && landlord != null && landlord != player) {
      engine.players[landlord].hand.forEach(take);
    }
    return counts;
  }
}
