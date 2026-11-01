import 'dart:math';

import '../models/playing_card.dart';
import 'combo.dart';
import 'combo_detector.dart';

enum GamePhase { idle, bidding, doubling, playing, finished, redeal }

/// 出牌校验结果。
enum PlayError {
  none(''),
  notYourTurn('还没轮到你出牌'),
  empty('请先选择要出的牌'),
  invalidCombo('所选牌型不合法'),
  cannotBeat('无法压过上家的牌'),
  cardsNotInHand('手牌校验失败，请重新选择'),
  mustPlay('本轮由你领出，不能不出');

  const PlayError(this.message);

  final String message;
}

class PlayOutcome {
  const PlayOutcome({this.error = PlayError.none, this.combo});

  final PlayError error;
  final Combo? combo;

  bool get ok => error == PlayError.none;
}

class PlayerState {
  PlayerState({required this.id, required this.name});

  final int id;
  final String name;
  final List<PlayingCard> hand = [];
  bool isLandlord = false;
  bool lastPassed = false;
  int playCount = 0;
  List<PlayingCard> lastPlay = const [];
  Combo? lastCombo;

  void sortHand() => hand.sort((a, b) => b.rank.compareTo(a.rank));

  void reset() {
    hand.clear();
    isLandlord = false;
    lastPassed = false;
    playCount = 0;
    lastPlay = const [];
    lastCombo = null;
  }
}

class GameResult {
  const GameResult({
    required this.landlordWon,
    required this.spring,
    required this.antiSpring,
    required this.multiplier,
    required this.scores,
    required this.winner,
    required this.landlord,
  });

  final bool landlordWon;
  final bool spring;
  final bool antiSpring;
  final int multiplier;
  final List<int> scores;
  final int winner;
  final int landlord;

  bool humanWon(bool isLandlord) => isLandlord ? landlordWon : !landlordWon;
}

/// 纯逻辑对局引擎：不依赖 Flutter，便于单元测试与回放。
class DdzEngine {
  DdzEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  final List<PlayerState> players = [
    PlayerState(id: 0, name: '你'),
    PlayerState(id: 1, name: '小智'),
    PlayerState(id: 2, name: '阿福'),
  ];

  List<PlayingCard> bottomCards = const [];
  GamePhase phase = GamePhase.idle;
  int currentPlayer = 0;
  int? landlord;
  Combo? lastCombo;
  int lastPlayer = -1;
  int passCount = 0;
  int multiplier = 1;
  int baseScore = 1;
  int highestBid = 0;
  int? highestBidder;
  int turnSerial = 0;
  int trickSerial = 0;
  String? lastActionText;
  GameResult? result;

  /// 每个玩家本局的叫分（0 表示不叫）。
  final Map<int, int> bids = {};

  /// 加倍顺序：地主先选，随后两名农民。
  final List<int> doublingQueue = [];
  int doublingIndex = 0;

  /// 本局所有已经打出的牌，供 AI 记牌使用。
  final List<PlayingCard> playedCards = [];

  PlayerState get current => players[currentPlayer];

  bool get allBidsIn => bids.length >= players.length;

  bool get allDoublingDone => doublingIndex >= doublingQueue.length;

  bool get isHumanTurn => phase == GamePhase.playing && currentPlayer == 0;

  int nextPlayer(int from) => (from + 1) % players.length;

  void start() {
    for (final player in players) {
      player.reset();
    }
    bids.clear();
    doublingQueue.clear();
    doublingIndex = 0;
    playedCards.clear();
    bottomCards = const [];
    landlord = null;
    highestBid = 0;
    highestBidder = null;
    baseScore = 1;
    lastCombo = null;
    lastPlayer = -1;
    passCount = 0;
    multiplier = 1;
    result = null;
    lastActionText = null;
    phase = GamePhase.bidding;
    trickSerial++;

    final deck = PlayingCard.createDeck()..shuffle(_random);
    for (var i = 0; i < 51; i++) {
      players[i % 3].hand.add(deck[i]);
    }
    bottomCards = deck.sublist(51);
    for (final player in players) {
      player.sortHand();
    }
    currentPlayer = _random.nextInt(3);
    turnSerial++;
  }

  /// 叫分：0 不叫，1-3 分必须高于当前最高分。返回是否被接受。
  bool bid(int playerId, int score) {
    if (phase != GamePhase.bidding || currentPlayer != playerId) return false;
    if (score < 0 || score > 3) return false;
    if (bids.containsKey(playerId)) return false;
    if (score > 0 && score <= highestBid) return false;

    bids[playerId] = score;
    final name = players[playerId].name;
    if (score > 0) {
      highestBid = score;
      highestBidder = playerId;
      lastActionText = '$name 叫 $score 分';
    } else {
      lastActionText = '$name 不叫';
    }

    if (score == 3 || allBidsIn) {
      final winner = highestBidder;
      if (winner == null) {
        phase = GamePhase.redeal;
        lastActionText = '三家都不叫，重新发牌';
      } else {
        _startLandlord(winner);
      }
      turnSerial++;
      return true;
    }

    currentPlayer = _nextBidder(playerId);
    turnSerial++;
    return true;
  }

  int _nextBidder(int from) {
    var next = nextPlayer(from);
    while (bids.containsKey(next)) {
      next = nextPlayer(next);
    }
    return next;
  }

  void _startLandlord(int playerId) {
    landlord = playerId;
    baseScore = highestBid;
    multiplier = baseScore;
    final player = players[playerId];
    player.isLandlord = true;
    player.hand.addAll(bottomCards);
    player.sortHand();
    lastActionText = '${player.name} 以 $baseScore 分成为地主';
    phase = GamePhase.doubling;
    doublingQueue
      ..clear()
      ..add(playerId)
      ..add(nextPlayer(playerId))
      ..add(nextPlayer(nextPlayer(playerId)));
    doublingIndex = 0;
    currentPlayer = playerId;
  }

  /// 加倍：true 使本局倍数再 ×2。返回是否被接受。
  bool doubleUp(int playerId, bool doubled) {
    if (phase != GamePhase.doubling || currentPlayer != playerId) return false;
    if (allDoublingDone) return false;

    final name = players[playerId].name;
    if (doubled) {
      multiplier *= 2;
      lastActionText = '$name 加倍，倍数 ×$multiplier';
    } else {
      lastActionText = '$name 不加倍';
    }

    doublingIndex++;
    if (allDoublingDone) {
      phase = GamePhase.playing;
      currentPlayer = landlord ?? playerId;
      lastCombo = null;
      lastPlayer = -1;
      passCount = 0;
      lastActionText = '加倍结束，${players[currentPlayer].name} 先出牌';
    } else {
      currentPlayer = doublingQueue[doublingIndex];
    }
    turnSerial++;
    return true;
  }

  PlayOutcome play(int playerId, List<PlayingCard> cards) {
    if (phase != GamePhase.playing || currentPlayer != playerId) {
      return const PlayOutcome(error: PlayError.notYourTurn);
    }
    if (cards.isEmpty) return const PlayOutcome(error: PlayError.empty);

    final ids = cards.map((card) => card.id).toSet();
    final handIds = players[playerId].hand.map((card) => card.id).toSet();
    if (ids.length != cards.length || !handIds.containsAll(ids)) {
      return const PlayOutcome(error: PlayError.cardsNotInHand);
    }

    final combo = detectCombo(cards);
    if (combo == null) {
      return const PlayOutcome(error: PlayError.invalidCombo);
    }
    if (lastCombo != null && !beatsCombo(combo, lastCombo)) {
      return const PlayOutcome(error: PlayError.cannotBeat);
    }

    final player = players[playerId];
    player.hand.removeWhere((card) => ids.contains(card.id));
    player.playCount++;
    player.lastPlay = combo.cards;
    player.lastCombo = combo;
    playedCards.addAll(combo.cards);
    for (final other in players) {
      other.lastPassed = false;
    }

    lastCombo = combo;
    lastPlayer = playerId;
    passCount = 0;
    if (combo.isBomb) {
      multiplier *= 2;
      lastActionText = '${player.name} 打出${combo.description}，倍数 ×$multiplier';
    } else {
      lastActionText = '${player.name} 打出${combo.description}';
    }

    if (player.hand.isEmpty) {
      _finish(playerId);
      return PlayOutcome(combo: combo);
    }

    currentPlayer = nextPlayer(playerId);
    turnSerial++;
    return PlayOutcome(combo: combo);
  }

  PlayError pass(int playerId) {
    if (phase != GamePhase.playing || currentPlayer != playerId) {
      return PlayError.notYourTurn;
    }
    if (lastCombo == null) return PlayError.mustPlay;

    final player = players[playerId];
    player.lastPassed = true;
    player.lastPlay = const [];
    player.lastCombo = null;
    passCount++;
    lastActionText = '${player.name} 不出';

    if (passCount >= 2) {
      currentPlayer = lastPlayer;
      lastCombo = null;
      passCount = 0;
      lastPlayer = -1;
      trickSerial++;
      for (final other in players) {
        other.lastPassed = false;
        other.lastPlay = const [];
        other.lastCombo = null;
      }
      lastActionText = '两家不出，${players[currentPlayer].name} 重新领出';
    } else {
      currentPlayer = nextPlayer(playerId);
    }
    turnSerial++;
    return PlayError.none;
  }

  void _finish(int winnerId) {
    phase = GamePhase.finished;
    final winner = players[winnerId];
    final landlordWon = winner.isLandlord;
    final landlordId = landlord ?? 0;
    var spring = false;
    var antiSpring = false;

    if (landlordWon) {
      spring = players.every((p) => p.isLandlord || p.playCount == 0);
      if (spring) multiplier *= 2;
    } else {
      antiSpring = players[landlordId].playCount == 1;
      if (antiSpring) multiplier *= 2;
    }

    final scores = List<int>.filled(players.length, 0);
    for (final player in players) {
      if (player.isLandlord) {
        scores[player.id] = landlordWon ? 2 * multiplier : -2 * multiplier;
      } else {
        scores[player.id] = landlordWon ? -multiplier : multiplier;
      }
    }

    result = GameResult(
      landlordWon: landlordWon,
      spring: spring,
      antiSpring: antiSpring,
      multiplier: multiplier,
      scores: scores,
      winner: winnerId,
      landlord: landlordId,
    );
    lastActionText = landlordWon ? '地主获胜' : '农民获胜';
    turnSerial++;
  }
}
