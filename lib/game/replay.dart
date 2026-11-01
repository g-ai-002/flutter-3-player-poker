import '../models/hand_record.dart';
import '../models/playing_card.dart';

/// 复盘的一帧：步骤标题、本步倍数与三家剩余手牌。
typedef ReplayStep = ({
  String title,
  int multiplier,
  List<List<PlayingCard>> hands,
});

/// 从牌谱还原开盘与每一手的三家手牌；旧牌谱没有开局手牌时仅回放动作。
List<ReplayStep> buildReplay(HandRecord record) {
  final source = record.initialHands;
  final hands = <List<PlayingCard>>[
    for (var i = 0; i < 3; i++)
      [...(i < source.length ? source[i] : const <PlayingCard>[])],
  ];
  final steps = <ReplayStep>[
    (title: '开局手牌', multiplier: 1, hands: _snapshot(hands)),
  ];
  final landlord = record.humanIsLandlord
      ? 0
      : record.playerNames.indexOf(record.landlordName);
  final lastBid = record.actions.lastIndexWhere(
    (action) => action.type == HandActionType.bid,
  );
  var multiplier = 1;
  for (var i = 0; i < record.actions.length; i++) {
    final action = record.actions[i];
    // 旧牌谱没有逐手倍数，回退到动作文案与底分。
    final parsed = int.tryParse(
      RegExp(r'×(\d+)').firstMatch(action.text)?.group(1) ?? '',
    );
    if (action.multiplier > multiplier) multiplier = action.multiplier;
    if (i == lastBid && record.baseScore > multiplier) {
      multiplier = record.baseScore;
    }
    if (parsed != null && parsed > multiplier) multiplier = parsed;
    if (action.player >= 0 && action.player < hands.length) {
      final hand = hands[action.player];
      if (action.type == HandActionType.play) {
        final ids = {for (final card in action.cards) card.id};
        hand.removeWhere((card) => ids.contains(card.id));
      } else if (i == lastBid && landlord >= 0 && landlord < hands.length) {
        hands[landlord].addAll(record.bottomCards);
        hands[landlord].sort(_descending);
      }
    }
    steps.add((
      title: action.text,
      multiplier: multiplier,
      hands: _snapshot(hands),
    ));
  }
  steps.add((
    title: record.outcomeLabel,
    multiplier: record.multiplier,
    hands: _snapshot(hands),
  ));
  return steps;
}

int _descending(PlayingCard a, PlayingCard b) {
  final byRank = b.rank.compareTo(a.rank);
  return byRank != 0 ? byRank : a.id.compareTo(b.id);
}

List<List<PlayingCard>> _snapshot(List<List<PlayingCard>> hands) => [
  for (final hand in hands) List<PlayingCard>.unmodifiable(hand),
];
