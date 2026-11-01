import 'package:flutter/foundation.dart';

import '../utils/formatters.dart';
import 'playing_card.dart';

/// 牌谱中的一步动作。
enum HandActionType {
  bid('叫分'),
  double('加倍'),
  reveal('明牌'),
  play('出牌'),
  pass('不出');

  const HandActionType(this.label);

  final String label;

  static HandActionType fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return HandActionType.play;
  }
}

@immutable
class HandAction {
  const HandAction({
    required this.player,
    required this.type,
    required this.text,
    this.cards = const [],
  });

  /// 玩家序号（0 为人类玩家）。
  final int player;
  final HandActionType type;

  /// 动作描述，直接取引擎生成的中文文案。
  final String text;
  final List<PlayingCard> cards;

  Map<String, dynamic> toJson() => {
    'player': player,
    'type': type.name,
    'text': text,
    'cards': PlayingCard.listToJson(cards),
  };

  factory HandAction.fromJson(Map<String, dynamic> json) => HandAction(
    player: json['player'] is num ? (json['player'] as num).toInt() : 0,
    type: HandActionType.fromName(json['type'] as String?),
    text: json['text'] is String ? json['text'] as String : '',
    cards: PlayingCard.listFromJson(json['cards']),
  );
}

/// 一局完整牌谱：结算数据 + 逐步动作，可持久化与导出。
@immutable
class HandRecord {
  const HandRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.humanIsLandlord,
    required this.landlordName,
    required this.landlordWon,
    required this.baseScore,
    required this.multiplier,
    required this.spring,
    required this.antiSpring,
    required this.revealed,
    required this.scores,
    required this.playerNames,
    required this.bottomCards,
    required this.actions,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool humanIsLandlord;
  final String landlordName;
  final bool landlordWon;
  final int baseScore;
  final int multiplier;
  final bool spring;
  final bool antiSpring;
  final bool revealed;

  /// 三家本局得分，下标即玩家序号。
  final List<int> scores;
  final List<String> playerNames;
  final List<PlayingCard> bottomCards;
  final List<HandAction> actions;

  bool get humanWon => humanIsLandlord ? landlordWon : !landlordWon;

  int get humanScore => scores.isEmpty ? 0 : scores.first;

  String get outcomeLabel {
    final tags = <String>[
      landlordWon ? '地主获胜' : '农民获胜',
      if (spring) '春天',
      if (antiSpring) '反春天',
    ];
    return '${tags.join(' · ')} · 倍数 ×$multiplier';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'humanIsLandlord': humanIsLandlord,
    'landlordName': landlordName,
    'landlordWon': landlordWon,
    'baseScore': baseScore,
    'multiplier': multiplier,
    'spring': spring,
    'antiSpring': antiSpring,
    'revealed': revealed,
    'scores': scores,
    'playerNames': playerNames,
    'bottomCards': PlayingCard.listToJson(bottomCards),
    'actions': [for (final action in actions) action.toJson()],
  };

  factory HandRecord.fromJson(Map<String, dynamic> json) {
    return HandRecord(
      id: json['id'] is String ? json['id'] as String : '',
      startedAt:
          _readDate(json['startedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt:
          _readDate(json['endedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      humanIsLandlord: json['humanIsLandlord'] == true,
      landlordName: json['landlordName'] is String
          ? json['landlordName'] as String
          : '',
      landlordWon: json['landlordWon'] == true,
      baseScore: _readInt(json['baseScore']),
      multiplier: _readInt(json['multiplier']),
      spring: json['spring'] == true,
      antiSpring: json['antiSpring'] == true,
      revealed: json['revealed'] == true,
      scores: _readIntList(json['scores']),
      playerNames: json['playerNames'] is List
          ? [for (final name in json['playerNames'] as List) '$name']
          : const [],
      bottomCards: PlayingCard.listFromJson(json['bottomCards']),
      actions: json['actions'] is List
          ? [
              for (final item in json['actions'] as List)
                if (item is Map<String, dynamic>) HandAction.fromJson(item),
            ]
          : const [],
    );
  }

  /// 纯文本牌谱：剪贴板与导出文件共用同一份内容。
  String toText() {
    final buffer = StringBuffer()
      ..writeln('斗地主 · 牌谱')
      ..writeln('时间: ${formatDateTime(startedAt)}')
      ..writeln(
        '身份: ${humanIsLandlord ? '地主' : '农民'} · 地主 $landlordName'
        '（底分 $baseScore）',
      )
      ..writeln('结果: $outcomeLabel')
      ..writeln('得分: ${_scoreLine()}')
      ..writeln(
        '底牌: ${bottomCards.isEmpty ? '—' : bottomCards.map((c) => c.displayName).join(' ')}',
      );
    if (revealed) buffer.writeln('明牌: 地主已亮牌');
    buffer
      ..writeln()
      ..writeln('出牌记录');
    for (var i = 0; i < actions.length; i++) {
      buffer.writeln('${i + 1}. ${actions[i].text}');
    }
    return buffer.toString();
  }

  String _scoreLine() {
    if (playerNames.isEmpty) return '—';
    final parts = <String>[];
    for (var i = 0; i < playerNames.length; i++) {
      final score = i < scores.length ? scores[i] : 0;
      parts.add('${playerNames[i]} ${score >= 0 ? '+' : ''}$score');
    }
    return parts.join(' / ');
  }
}

int _readInt(Object? value) => value is num ? value.toInt() : 0;

DateTime? _readDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

List<int> _readIntList(Object? value) =>
    value is List ? [for (final item in value) _readInt(item)] : const [];
