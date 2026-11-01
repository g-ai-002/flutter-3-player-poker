import 'dart:math';

import '../models/playing_card.dart';
import 'combo.dart';
import 'game_engine.dart';
import 'hand_analyzer.dart';

/// 规则型 AI：不记牌、不做搜索，专注稳定与可解释。
///
/// - 叫地主：按王、2、炸弹与 A 的数量评分；
/// - 跟牌：同类最小压制，农民不压队友，炸弹只在关键局面使用；
/// - 领出：优先出小牌，能一手走完则直接结束。
class AiPlayer {
  AiPlayer({Random? random, this.analyzer = const HandAnalyzer()})
    : _random = random ?? Random();

  final Random _random;
  final HandAnalyzer analyzer;

  bool shouldCall(List<PlayingCard> hand) {
    final strength = _strength(hand);
    return strength >= 4.6 + _random.nextDouble() * 0.9;
  }

  /// 当前玩家的决策；返回 null 表示不出。
  List<PlayingCard>? choose(DdzEngine engine) {
    final player = engine.current;
    final target = engine.lastCombo;
    if (target == null) return _chooseLead(player.hand);

    final options = analyzer.beatingCandidates(player.hand, target);
    if (options.isEmpty) return null;

    final finisher = options.where(
      (combo) => combo.cards.length == player.hand.length,
    );
    if (finisher.isNotEmpty) return finisher.first.cards;

    final teammate =
        !player.isLandlord &&
        engine.lastPlayer >= 0 &&
        !engine.players[engine.lastPlayer].isLandlord;
    if (teammate) return null;

    final normal = options.where((combo) => !combo.isBomb).toList()
      ..sort(_compareBeat);
    if (normal.isNotEmpty) return normal.first.cards;

    final urgent =
        engine.lastPlayer >= 0 &&
        (engine.players[engine.lastPlayer].hand.length <= 2 ||
            player.hand.length <= 4);
    if (!urgent) return null;
    options.sort(_compareBeat);
    return options.first.cards;
  }

  /// 人类玩家的提示：优先普通牌型，没有时才提示炸弹。
  List<PlayingCard>? hint(DdzEngine engine) {
    final player = engine.players[0];
    final target = engine.lastCombo;
    if (target == null) return _chooseLead(player.hand);
    final options = analyzer.beatingCandidates(player.hand, target);
    if (options.isEmpty) return null;
    options.sort(_compareBeat);
    final normal = options.where((combo) => !combo.isBomb);
    return (normal.isNotEmpty ? normal.first : options.first).cards;
  }

  List<PlayingCard>? _chooseLead(List<PlayingCard> hand) {
    final options = analyzer.leadCandidates(hand);
    if (options.isEmpty) return null;

    final finisher = options.where(
      (combo) => combo.cards.length == hand.length,
    );
    if (finisher.isNotEmpty) return finisher.first.cards;

    final normal = options.where((combo) => !combo.isBomb).toList();
    final pool = normal.isNotEmpty ? normal : options;
    pool.sort((a, b) => _leadScore(a).compareTo(_leadScore(b)));
    return pool.first.cards;
  }

  int _compareBeat(Combo a, Combo b) {
    if (a.isBomb != b.isBomb) return a.isBomb ? 1 : -1;
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    return a.cards.length.compareTo(b.cards.length);
  }

  /// 分数越低越优先：小牌优先，同等点数下多出几张以减少手牌。
  int _leadScore(Combo combo) {
    var score = combo.rank * 100 - combo.cards.length * 8;
    score -= switch (combo.type) {
      ComboType.straight => 25,
      ComboType.straightPair => 30,
      ComboType.plane => 30,
      ComboType.planeSingle => 25,
      ComboType.planePair => 30,
      ComboType.tripleSingle => 15,
      ComboType.triplePair => 15,
      ComboType.fourTwoSingle => 20,
      ComboType.fourTwoPair => 25,
      _ => 0,
    };
    return score;
  }

  double _strength(List<PlayingCard> hand) {
    var score = 0.0;
    final counts = <int, int>{};
    for (final card in hand) {
      counts[card.rank] = (counts[card.rank] ?? 0) + 1;
      if (card.rank == 17) score += 4;
      if (card.rank == 16) score += 3;
      if (card.rank == 15) score += 1;
      if (card.rank == 14) score += 0.4;
    }
    for (final count in counts.values) {
      if (count == 4) score += 4;
    }
    if (counts[16] == 1 && counts[17] == 1) score += 3;
    return score;
  }
}
