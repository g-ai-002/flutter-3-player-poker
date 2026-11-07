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

/// 牌桌逻辑更新速率：与屏幕刷新率解耦的固定步长。
enum LogicRate {
  hz30('30Hz', 30, '逻辑步减半，最省电，动画略粗'),
  hz60('60Hz', 60, '默认，兼顾性能与流畅度'),
  hz120('120Hz', 120, '适合高刷屏，逻辑更顺滑，也更耗电');

  const LogicRate(this.label, this.hz, this.description);

  final String label;
  final int hz;
  final String description;

  static LogicRate fromHertz(int? hz) {
    for (final value in values) {
      if (value.hz == hz) return value;
    }
    return LogicRate.hz60;
  }
}
