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
    if (target == null) {
      return _chooseLead(
        player.hand,
        avoidSingles: _opponentAboutToWin(engine, player),
      );
    }

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
    if (normal.isNotEmpty) {
      // 不为压一张小牌拆掉炸弹或王炸；残局必须拦牌时才破例。
      final safe = normal
          .where((combo) => !_breaksBomb(player.hand, combo))
          .toList();
      if (safe.isNotEmpty) return safe.first.cards;
      if (!_mustBlock(engine, player)) return null;
      return normal.first.cards;
    }

    final urgent = _mustBlock(engine, player);
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

  /// 领出：小牌优先；不拆炸弹与王炸；对手只剩一张时避免送单张。
  List<PlayingCard>? _chooseLead(
    List<PlayingCard> hand, {
    bool avoidSingles = false,
  }) {
    final options = analyzer.leadCandidates(hand);
    if (options.isEmpty) return null;

    final finisher = options.where(
      (combo) => combo.cards.length == hand.length,
    );
    if (finisher.isNotEmpty) return finisher.first.cards;

    final normal = options.where((combo) => !combo.isBomb).toList();
    final base = normal.isNotEmpty ? normal : options;
    final safe = base.where((combo) => !_breaksBomb(hand, combo)).toList();
    var pool = safe.isNotEmpty ? safe : base;
    if (avoidSingles) {
      final multi = pool.where((combo) => combo.cards.length > 1).toList();
      if (multi.isNotEmpty) pool = multi;
    }
    pool.sort((a, b) => _leadScore(a).compareTo(_leadScore(b)));
    return pool.first.cards;
  }

  /// 出牌会拆散手牌中的炸弹或王炸。
  bool _breaksBomb(List<PlayingCard> hand, Combo combo) {
    if (combo.isBomb) return false;
    final counts = <int, int>{};
    for (final card in hand) {
      counts[card.rank] = (counts[card.rank] ?? 0) + 1;
    }
    const rocketLow = 16;
    const rocketHigh = 17;
    if (counts[rocketLow] == 1 &&
        counts[rocketHigh] == 1 &&
        combo.cards.any((card) => card.isJoker)) {
      return true;
    }
    for (final entry in counts.entries) {
      if (entry.value != 4) continue;
      if (combo.cards.any((card) => card.rank == entry.key)) return true;
    }
    return false;
  }

  /// 对手（不同阵营）只剩一张牌，必须主动压制。
  bool _opponentAboutToWin(DdzEngine engine, PlayerState player) {
    return engine.players.any(
      (other) =>
          other.id != player.id &&
          other.isLandlord != player.isLandlord &&
          other.hand.length == 1,
    );
  }

  bool _mustBlock(DdzEngine engine, PlayerState player) {
    final lastPlayer = engine.lastPlayer;
    final opponentNearWin =
        lastPlayer >= 0 &&
        engine.players[lastPlayer].isLandlord != player.isLandlord &&
        engine.players[lastPlayer].hand.length <= 2;
    return opponentNearWin || player.hand.length <= 4;
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
