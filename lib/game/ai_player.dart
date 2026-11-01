import 'dart:math';

import '../models/app_settings.dart';
import '../models/playing_card.dart';
import 'combo.dart';
import 'game_engine.dart';
import 'hand_analyzer.dart';

/// 规则型 AI，按难度提供三档棋力。
///
/// - 叫分：按王、2、炸弹与 A 的数量评分，叫分必须高于当前最高分；
/// - 跟牌：同类最小压制，农民不压队友，炸弹只在关键局面使用；
/// - 领出：优先出小牌，能一手走完则直接结束；
/// - 高手：记住已出的牌，用剩余手数评估拆牌，保留控制牌。
class AiPlayer {
  AiPlayer({
    Random? random,
    this.analyzer = const HandAnalyzer(),
    this.level = AiLevel.normal,
  }) : _random = random ?? Random();

  final Random _random;
  final HandAnalyzer analyzer;

  /// 由设置页控制，对局中切换后下一次决策即生效。
  AiLevel level;

  /// 当前玩家的叫分；0 表示不叫。保证高于桌面上已有的最高分。
  int bidScore(DdzEngine engine) {
    return bidScoreFor(engine.current.hand, engine.highestBid);
  }

  int bidScoreFor(List<PlayingCard> hand, int highestBid) {
    final strength = _strength(hand);
    var score = 0;
    if (strength >= 9.5) {
      score = 3;
    } else if (strength >= 6.8) {
      score = 2;
    } else if (strength >= 4.6) {
      score = 1;
    }

    switch (level) {
      case AiLevel.easy:
        if (score > 0 && _random.nextDouble() < 0.45) score = 0;
      case AiLevel.normal:
      case AiLevel.hard:
        break;
    }
    if (score <= highestBid) return 0;
    return score;
  }

  /// 加倍决策：牌力越强越愿意加倍，农民门槛低于地主。
  bool shouldDouble(DdzEngine engine) {
    final player = engine.current;
    final strength = _strength(player.hand);
    final threshold = player.isLandlord ? 7.0 : 5.5;
    final adjust = switch (level) {
      AiLevel.easy => 1.5,
      AiLevel.normal => 0.0,
      AiLevel.hard => -1.2,
    };
    var want = strength >= threshold + adjust;
    if (level == AiLevel.easy && _random.nextDouble() < 0.4) want = false;
    return want;
  }

  /// 明牌决策：只有高手地主会亮牌，手牌足够强时才用翻倍换压力。
  bool shouldReveal(DdzEngine engine) {
    final player = engine.current;
    if (level != AiLevel.hard || !player.isLandlord) return false;
    return _strength(player.hand) >= 9.0;
  }

  /// 当前玩家的决策；返回 null 表示不出。
  List<PlayingCard>? choose(DdzEngine engine) {
    final player = engine.current;
    final target = engine.lastCombo;
    final unseen = level == AiLevel.hard ? _unseenCards(engine) : null;
    if (target == null) {
      return _chooseLead(
        player.hand,
        avoidSingles: _opponentAboutToWin(engine, player),
        unseen: unseen,
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

    final urgent = _mustBlock(engine, player);
    if (level == AiLevel.easy && !urgent && _random.nextDouble() < 0.3) {
      return null;
    }

    final normal = options.where((combo) => !combo.isBomb).toList()
      ..sort(_compareBeat);
    if (normal.isNotEmpty) {
      // 不为压一张小牌拆掉炸弹或王炸；残局必须拦牌时才破例。
      final safe = normal
          .where((combo) => !_breaksBomb(player.hand, combo))
          .toList();
      if (safe.isNotEmpty) {
        if (level != AiLevel.hard) return safe.first.cards;
        return _bestByHandCount(player.hand, safe);
      }
      if (!urgent) return null;
      return normal.first.cards;
    }

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
    Map<int, int>? unseen,
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

    if (level == AiLevel.hard && unseen != null) {
      final counts = <String, int>{
        for (final combo in pool) combo.signature: _remainingPlays(hand, combo),
      };
      pool.sort((a, b) {
        final byCount = counts[a.signature]!.compareTo(counts[b.signature]!);
        if (byCount != 0) return byCount;
        final byControl = _controlPenalty(
          a,
          unseen,
        ).compareTo(_controlPenalty(b, unseen));
        return byControl != 0
            ? byControl
            : _leadScore(a).compareTo(_leadScore(b));
      });
      return pool.first.cards;
    }

    pool.sort((a, b) => _leadScore(a).compareTo(_leadScore(b)));
    if (level == AiLevel.easy && pool.length > 1) {
      final top = pool.take(min(3, pool.length)).toList();
      if (_random.nextDouble() < 0.4) {
        return top[_random.nextInt(top.length)].cards;
      }
    }
    return pool.first.cards;
  }

  /// 高手：在能压住的牌里选打出后剩余手数最少的。
  List<PlayingCard> _bestByHandCount(
    List<PlayingCard> hand,
    List<Combo> options,
  ) {
    Combo? best;
    var bestCount = 0;
    for (final combo in options) {
      final count = _remainingPlays(hand, combo);
      if (best == null || count < bestCount) {
        best = combo;
        bestCount = count;
      }
    }
    return best!.cards;
  }

  int _remainingPlays(List<PlayingCard> hand, Combo combo) {
    final ids = combo.cards.map((card) => card.id).toSet();
    final rest = hand.where((card) => !ids.contains(card.id)).toList();
    return analyzer.estimatePlays(rest);
  }

  /// 高手记牌：从整副牌中扣掉自己手牌与所有已出牌。
  Map<int, int> _unseenCards(DdzEngine engine) {
    final counts = <int, int>{
      for (var rank = 3; rank <= 15; rank++) rank: 4,
      16: 1,
      17: 1,
    };
    void remove(PlayingCard card) {
      counts[card.rank] = (counts[card.rank] ?? 0) - 1;
    }

    for (final card in engine.playedCards) {
      remove(card);
    }
    for (final card in engine.current.hand) {
      remove(card);
    }
    return counts;
  }

  /// 出掉一张对手无法压制的牌会失去控制力，稍微降低优先级。
  int _controlPenalty(Combo combo, Map<int, int> unseen) {
    var penalty = 0;
    for (final card in combo.cards) {
      if (card.isJoker) continue;
      var higher = 0;
      for (var rank = card.rank + 1; rank <= 17; rank++) {
        higher += unseen[rank] ?? 0;
      }
      if (higher == 0) penalty += 8;
    }
    return penalty;
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
