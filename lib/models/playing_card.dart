import 'package:flutter/foundation.dart';

/// 花色；大小王单独归入 [CardSuit.joker]。
enum CardSuit { spade, heart, club, diamond, joker }

/// 一张扑克牌。
///
/// 点数取值：3-10 为本身，11-14 为 J/Q/K/A，15 为 2，
/// 16 为小王，17 为大王。斗地主比较只看点数，花色仅用于展示。
@immutable
class PlayingCard {
  const PlayingCard({required this.id, required this.rank, required this.suit});

  /// 牌堆内唯一编号（0-53），用于选中与校验，重复点数也不会混淆。
  final int id;
  final int rank;
  final CardSuit suit;

  bool get isJoker => rank >= 16;

  bool get isRed =>
      suit == CardSuit.heart || suit == CardSuit.diamond || rank == 17;

  String get rankLabel => switch (rank) {
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    14 => 'A',
    15 => '2',
    16 => '小',
    17 => '大',
    _ => '$rank',
  };

  String get suitSymbol => switch (suit) {
    CardSuit.spade => '♠',
    CardSuit.heart => '♥',
    CardSuit.club => '♣',
    CardSuit.diamond => '♦',
    CardSuit.joker => '',
  };

  /// 完整名称：`♠A` / `大王`，用于日志与牌谱。
  String get displayName => switch (rank) {
    16 => '小王',
    17 => '大王',
    _ => '$suitSymbol$rankLabel',
  };

  /// 生成一副 54 张牌，id 固定，便于测试复现。
  static List<PlayingCard> createDeck() {
    final deck = <PlayingCard>[];
    var id = 0;
    for (var rank = 3; rank <= 15; rank++) {
      for (final suit in const [
        CardSuit.spade,
        CardSuit.heart,
        CardSuit.club,
        CardSuit.diamond,
      ]) {
        deck.add(PlayingCard(id: id++, rank: rank, suit: suit));
      }
    }
    deck.add(PlayingCard(id: id++, rank: 16, suit: CardSuit.joker));
    deck.add(PlayingCard(id: id++, rank: 17, suit: CardSuit.joker));
    return deck;
  }

  @override
  String toString() => displayName;
}
