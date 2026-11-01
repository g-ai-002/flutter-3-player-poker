import 'package:flutter/foundation.dart';

import '../models/playing_card.dart';

/// 斗地主牌型。
enum ComboType {
  single('单张'),
  pair('对子'),
  triple('三张'),
  tripleSingle('三带一'),
  triplePair('三带二'),
  straight('顺子'),
  straightPair('连对'),
  plane('飞机'),
  planeSingle('飞机带单'),
  planePair('飞机带对'),
  fourTwoSingle('四带二'),
  fourTwoPair('四带两对'),
  bomb('炸弹'),
  rocket('王炸');

  const ComboType(this.label);

  final String label;
}

/// 一次合法出牌。
///
/// [rank] 为比较用的主点数（顺子取最大牌、飞机取最后一张三张），
/// [length] 为连续组数（顺子为张数，非连续牌型为 1）。
@immutable
class Combo {
  const Combo({
    required this.type,
    required this.rank,
    required this.length,
    required this.cards,
  });

  final ComboType type;
  final int rank;
  final int length;
  final List<PlayingCard> cards;

  bool get isBomb => type == ComboType.bomb || type == ComboType.rocket;

  /// 去重签名：同牌型同点数结构视为同一候选。
  String get signature {
    final ranks = cards.map((c) => c.rank).toList()..sort();
    return '${type.name}:${ranks.join(',')}';
  }

  String get description => switch (type) {
    ComboType.straight => '${type.label} · ${cards.length} 张',
    ComboType.straightPair => '${type.label} · $length 连',
    ComboType.plane => '${type.label} · $length 连',
    ComboType.planeSingle => '${type.label} · $length 连',
    ComboType.planePair => '${type.label} · $length 连',
    _ => type.label,
  };

  @override
  String toString() =>
      '$description(${cards.map((c) => c.displayName).join(' ')})';
}
