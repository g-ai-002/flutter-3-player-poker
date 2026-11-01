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

  /// 整副牌各点数的张数：3-15 各 4 张，大小王各 1 张。
  static final Map<int, int> rankTotals = {
    for (var rank = 3; rank <= 15; rank++) rank: 4,
    16: 1,
    17: 1,
  };

  /// 点数 -> 张数；记牌器、AI 记牌与牌型识别共用。
  static Map<int, int> rankCounts(Iterable<PlayingCard> cards) {
    final counts = <int, int>{};
    for (final card in cards) {
      counts[card.rank] = (counts[card.rank] ?? 0) + 1;
    }
    return counts;
  }

  /// 牌面角标：J/Q/K/A/2，大小王用「小 / 大」。
  static String rankLabelOf(int rank) => switch (rank) {
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    14 => 'A',
    15 => '2',
    16 => '小',
    17 => '大',
    _ => '$rank',
  };

  /// 口播与统计用的点数名称：小王 / 大王。
  static String rankName(int rank) => switch (rank) {
    16 => '小王',
    17 => '大王',
    _ => rankLabelOf(rank),
  };

  String get rankLabel => rankLabelOf(rank);

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

  Map<String, Object> toJson() => {'id': id, 'rank': rank, 'suit': suit.index};

  /// 从牌谱 JSON 还原一张牌；字段缺失或越界时返回 null。
  static PlayingCard? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final rank = value['rank'];
    final suit = value['suit'];
    if (id is! num || rank is! num || suit is! num) return null;
    final rankValue = rank.toInt();
    final suitIndex = suit.toInt();
    if (rankValue < 3 || rankValue > 17) return null;
    if (suitIndex < 0 || suitIndex >= CardSuit.values.length) return null;
    return PlayingCard(
      id: id.toInt(),
      rank: rankValue,
      suit: CardSuit.values[suitIndex],
    );
  }

  static List<PlayingCard> listFromJson(Object? value) {
    if (value is! List) return const [];
    final cards = <PlayingCard>[];
    for (final item in value) {
      final card = tryFromJson(item);
      if (card != null) cards.add(card);
    }
    return cards;
  }

  static List<Map<String, Object>> listToJson(Iterable<PlayingCard> cards) => [
    for (final card in cards) card.toJson(),
  ];

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
