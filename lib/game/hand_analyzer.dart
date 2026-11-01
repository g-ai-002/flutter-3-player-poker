import '../models/playing_card.dart';
import 'combo.dart';
import 'combo_detector.dart';

/// 从手牌中生成候选出牌。
///
/// 同时服务于 AI 决策与「提示」按钮：提示直接取这里的最小候选，
/// 因此提示给出的牌一定能通过引擎校验。
class HandAnalyzer {
  const HandAnalyzer();

  /// 自由出牌时的候选（不包含重复点数结构）。
  List<Combo> leadCandidates(List<PlayingCard> hand) {
    final groups = _group(hand);
    final result = <Combo>[];
    final seen = <String>{};

    void add(List<PlayingCard>? cards) {
      if (cards == null) return;
      final combo = detectCombo(cards);
      if (combo == null) return;
      if (seen.add(combo.signature)) result.add(combo);
    }

    for (final entry in groups.entries) {
      final rank = entry.key;
      final cards = entry.value;
      add([cards.first]);
      if (cards.length >= 2) add(cards.take(2).toList());
      if (cards.length >= 3) {
        add(cards.take(3).toList());
        add(_withSingles(groups, [rank], 3, 1));
        add(_withPairs(groups, [rank], 3, 1));
      }
      if (cards.length >= 4) {
        add(cards.take(4).toList());
        add(_withSingles(groups, [rank], 4, 2));
        add(_withPairs(groups, [rank], 4, 2));
      }
    }

    if (groups.containsKey(16) && groups.containsKey(17)) {
      add([groups[16]!.first, groups[17]!.first]);
    }

    for (var length = 5; length <= 12; length++) {
      for (final ranks in _windows(groups, length, 1)) {
        add(_take(groups, ranks));
      }
    }
    for (var length = 3; length <= 12; length++) {
      for (final ranks in _windows(groups, length, 2)) {
        add(_take(groups, ranks, 2));
      }
    }
    for (var length = 2; length <= 6; length++) {
      for (final ranks in _windows(groups, length, 3)) {
        add(_take(groups, ranks, 3));
        add(_withSingles(groups, ranks, 3, length));
        add(_withPairs(groups, ranks, 3, length));
      }
    }
    return result;
  }

  /// [target] 为 null 时等价于 [leadCandidates]。
  List<Combo> beatingCandidates(List<PlayingCard> hand, Combo? target) {
    if (target == null) return leadCandidates(hand);
    if (target.type == ComboType.rocket) return const [];

    final groups = _group(hand);
    final result = <Combo>[];
    final seen = <String>{};
    void add(List<PlayingCard>? cards) {
      if (cards == null) return;
      final combo = detectCombo(cards);
      if (combo == null || !beatsCombo(combo, target)) return;
      if (seen.add(combo.signature)) result.add(combo);
    }

    for (final entry in groups.entries) {
      final rank = entry.key;
      if (rank <= target.rank) continue;
      final cards = entry.value;
      switch (target.type) {
        case ComboType.single:
          add([cards.first]);
        case ComboType.pair:
          if (cards.length >= 2) add(cards.take(2).toList());
        case ComboType.triple:
          if (cards.length >= 3) add(cards.take(3).toList());
        case ComboType.tripleSingle:
          if (cards.length >= 3) add(_withSingles(groups, [rank], 3, 1));
        case ComboType.triplePair:
          if (cards.length >= 3) add(_withPairs(groups, [rank], 3, 1));
        case ComboType.straight:
          for (final ranks in _windows(groups, target.length, 1)) {
            if (ranks.last > target.rank) add(_take(groups, ranks));
          }
        case ComboType.straightPair:
          for (final ranks in _windows(groups, target.length, 2)) {
            if (ranks.last > target.rank) add(_take(groups, ranks, 2));
          }
        case ComboType.plane:
          for (final ranks in _windows(groups, target.length, 3)) {
            if (ranks.last > target.rank) add(_take(groups, ranks, 3));
          }
        case ComboType.planeSingle:
          for (final ranks in _windows(groups, target.length, 3)) {
            if (ranks.last <= target.rank) continue;
            add(_withSingles(groups, ranks, 3, target.length));
          }
        case ComboType.planePair:
          for (final ranks in _windows(groups, target.length, 3)) {
            if (ranks.last <= target.rank) continue;
            add(_withPairs(groups, ranks, 3, target.length));
          }
        case ComboType.fourTwoSingle:
          if (cards.length >= 4) add(_withSingles(groups, [rank], 4, 2));
        case ComboType.fourTwoPair:
          if (cards.length >= 4) add(_withPairs(groups, [rank], 4, 2));
        case ComboType.bomb:
        case ComboType.rocket:
          break;
      }
    }

    for (final entry in groups.entries) {
      if (entry.value.length >= 4) {
        add(entry.value.take(4).toList());
      }
    }
    if (groups.containsKey(16) && groups.containsKey(17)) {
      add([groups[16]!.first, groups[17]!.first]);
    }
    return result;
  }

  Map<int, List<PlayingCard>> _group(List<PlayingCard> hand) {
    final groups = <int, List<PlayingCard>>{};
    for (final card in hand) {
      groups.putIfAbsent(card.rank, () => []).add(card);
    }
    for (final cards in groups.values) {
      cards.sort((a, b) => a.id.compareTo(b.id));
    }
    return groups;
  }

  /// [length] 组连续点数，每组至少 [minCount] 张。
  List<List<int>> _windows(
    Map<int, List<PlayingCard>> groups,
    int length,
    int minCount,
  ) {
    final result = <List<int>>[];
    for (var start = 3; start + length - 1 <= 14; start++) {
      var ok = true;
      final ranks = <int>[];
      for (var rank = start; rank < start + length; rank++) {
        if ((groups[rank]?.length ?? 0) < minCount) {
          ok = false;
          break;
        }
        ranks.add(rank);
      }
      if (ok) result.add(ranks);
    }
    return result;
  }

  List<PlayingCard>? _take(
    Map<int, List<PlayingCard>> groups,
    List<int> ranks, [
    int each = 1,
  ]) {
    final cards = <PlayingCard>[];
    for (final rank in ranks) {
      final list = groups[rank];
      if (list == null || list.length < each) return null;
      cards.addAll(list.take(each));
    }
    return cards;
  }

  /// 主体 + [count] 个单张翅膀；优先拆散单张，避免拆对子/三张。
  List<PlayingCard>? _withSingles(
    Map<int, List<PlayingCard>> groups,
    List<int> bodyRanks,
    int bodyEach,
    int count,
  ) {
    final body = _take(groups, bodyRanks, bodyEach);
    if (body == null) return null;
    final rest = Map<int, List<PlayingCard>>.from(groups)
      ..removeWhere((rank, _) => bodyRanks.contains(rank));
    final wings = _takeSingles(rest, count);
    if (wings == null) return null;
    return [...body, ...wings];
  }

  List<PlayingCard>? _takeSingles(
    Map<int, List<PlayingCard>> groups,
    int count,
  ) {
    final cards = <PlayingCard>[];
    final entries = groups.entries.toList()
      ..sort((a, b) {
        final byCount = a.value.length.compareTo(b.value.length);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    for (final entry in entries) {
      for (final card in entry.value.take(2)) {
        cards.add(card);
        if (cards.length == count) return cards;
      }
    }
    return null;
  }

  List<PlayingCard>? _withPairs(
    Map<int, List<PlayingCard>> groups,
    List<int> bodyRanks,
    int bodyEach,
    int pairCount,
  ) {
    final body = _take(groups, bodyRanks, bodyEach);
    if (body == null) return null;
    final rest = Map<int, List<PlayingCard>>.from(groups)
      ..removeWhere((rank, _) => bodyRanks.contains(rank));
    final pairs =
        rest.entries.where((entry) => entry.value.length >= 2).toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    if (pairs.length < pairCount) return null;
    final cards = <PlayingCard>[...body];
    for (final entry in pairs.take(pairCount)) {
      cards.addAll(entry.value.take(2));
    }
    return cards;
  }
}
