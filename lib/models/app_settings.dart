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
