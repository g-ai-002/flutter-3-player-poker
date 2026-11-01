/// AI 思考速度，同时决定出牌节奏。
enum AiSpeed {
  fast('快速', 350),
  normal('标准', 850),
  slow('从容', 1400);

  const AiSpeed(this.label, this.delayMs);

  final String label;
  final int delayMs;

  static AiSpeed fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return AiSpeed.normal;
  }
}

/// AI 棋力：入门保守、标准规则、高手记牌并评估拆牌。
enum AiLevel {
  easy('入门', '更早放弃压牌，适合熟悉牌型'),
  normal('标准', '规则完整，跟牌克制、不拆炸弹'),
  hard('高手', '记牌判断控制力，按最少手数拆分出牌');

  const AiLevel(this.label, this.description);

  final String label;
  final String description;

  static AiLevel fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return AiLevel.normal;
  }
}
