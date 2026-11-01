import '../models/playing_card.dart';
import 'combo.dart';

/// 识别 [cards] 的牌型，非法组合返回 null。
///
/// 判定顺序：王炸/炸弹 → 基础牌型 → 三带 → 顺子/连对 → 飞机 → 四带二。
/// 带翅膀的牌型要求翅膀点数不与飞机主体重复，避免把四张拆成三带一。
Combo? detectCombo(List<PlayingCard> cards) {
  if (cards.isEmpty) return null;
  final counts = PlayingCard.rankCounts(cards);
  final n = cards.length;
  final ranks = counts.keys.toList()..sort();
  final sortedCards = [...cards]..sort((a, b) => a.rank.compareTo(b.rank));

  Combo make(ComboType type, int rank, int length) =>
      Combo(type: type, rank: rank, length: length, cards: sortedCards);

  if (n == 2 &&
      counts.length == 2 &&
      counts.containsKey(16) &&
      counts.containsKey(17)) {
    return make(ComboType.rocket, 17, 1);
  }
  if (n == 4 && counts.length == 1) {
    return make(ComboType.bomb, ranks.first, 1);
  }
  if (n == 1) return make(ComboType.single, ranks.first, 1);
  if (n == 2 && counts.length == 1) {
    return make(ComboType.pair, ranks.first, 1);
  }
  if (n == 3 && counts.length == 1) {
    return make(ComboType.triple, ranks.first, 1);
  }

  if (n == 4) {
    final triple = _rankWithCount(counts, 3);
    if (triple != null) return make(ComboType.tripleSingle, triple, 1);
  }
  if (n == 5) {
    final triple = _rankWithCount(counts, 3);
    final pair = _rankWithCount(counts, 2);
    if (triple != null && pair != null && counts.length == 2) {
      return make(ComboType.triplePair, triple, 1);
    }
  }

  if (_isStraight(n, counts, ranks)) {
    return make(ComboType.straight, ranks.last, n);
  }
  if (_isStraightPair(n, counts, ranks)) {
    return make(ComboType.straightPair, ranks.last, ranks.length);
  }
  if (_isPlane(n, counts, ranks)) {
    return make(ComboType.plane, ranks.last, ranks.length);
  }

  final four = _rankWithCount(counts, 4);
  if (n == 6 && four != null) {
    return make(ComboType.fourTwoSingle, four, 1);
  }
  if (n == 8 && four != null) {
    final rest = Map<int, int>.from(counts)..remove(four);
    final twoPairs =
        rest.length == 2 && rest.values.every((count) => count == 2);
    if (twoPairs) return make(ComboType.fourTwoPair, four, 1);
  }

  if (n % 4 == 0) {
    final k = n ~/ 4;
    if (k >= 2) {
      final combo = _planeWithWings(counts, k, pairWings: false, make: make);
      if (combo != null) return combo;
    }
  }
  if (n % 5 == 0) {
    final k = n ~/ 5;
    if (k >= 2) {
      final combo = _planeWithWings(counts, k, pairWings: true, make: make);
      if (combo != null) return combo;
    }
  }

  return null;
}

/// 判断 [candidate] 能否压过 [previous]；previous 为 null 表示自由出牌。
bool beatsCombo(Combo? candidate, Combo? previous) {
  if (candidate == null) return false;
  if (previous == null) return true;
  if (previous.type == ComboType.rocket) return false;
  if (candidate.type == ComboType.rocket) return true;
  if (previous.type == ComboType.bomb) {
    return candidate.type == ComboType.bomb && candidate.rank > previous.rank;
  }
  if (candidate.type == ComboType.bomb) return true;
  if (candidate.type != previous.type) return false;
  if (candidate.length != previous.length) return false;
  return candidate.rank > previous.rank;
}

int? _rankWithCount(Map<int, int> counts, int count) {
  for (final entry in counts.entries) {
    if (entry.value == count) return entry.key;
  }
  return null;
}

bool _consecutive(List<int> ranks) {
  for (var i = 1; i < ranks.length; i++) {
    if (ranks[i] != ranks[i - 1] + 1) return false;
  }
  return true;
}

bool _isStraight(int n, Map<int, int> counts, List<int> ranks) =>
    n >= 5 && counts.length == n && ranks.last < 15 && _consecutive(ranks);

bool _isStraightPair(int n, Map<int, int> counts, List<int> ranks) =>
    n >= 6 &&
    n.isEven &&
    ranks.length >= 3 &&
    ranks.last < 15 &&
    counts.values.every((count) => count == 2) &&
    _consecutive(ranks);

bool _isPlane(int n, Map<int, int> counts, List<int> ranks) =>
    n >= 6 &&
    n % 3 == 0 &&
    ranks.length >= 2 &&
    ranks.last < 15 &&
    counts.values.every((count) => count == 3) &&
    _consecutive(ranks);

/// 在连续的三张中寻找长度为 [k] 的一组，并校验剩余牌能否作为翅膀。
Combo? _planeWithWings(
  Map<int, int> counts,
  int k, {
  required bool pairWings,
  required Combo Function(ComboType type, int rank, int length) make,
}) {
  final triples =
      counts.entries
          .where((entry) => entry.value == 3 && entry.key < 15)
          .map((entry) => entry.key)
          .toList()
        ..sort();
  for (var start = 0; start + k <= triples.length; start++) {
    final run = triples.sublist(start, start + k);
    if (!_consecutive(run)) continue;
    final rest = Map<int, int>.from(counts);
    for (final rank in run) {
      rest.remove(rank);
    }
    final remaining = rest.values.fold<int>(0, (sum, value) => sum + value);
    if (pairWings) {
      if (remaining != k * 2) continue;
      if (rest.values.any((value) => value != 2)) continue;
      return make(ComboType.planePair, run.last, k);
    }
    if (remaining != k) continue;
    if (rest.values.any((value) => value > 2)) continue;
    return make(ComboType.planeSingle, run.last, k);
  }
  return null;
}
