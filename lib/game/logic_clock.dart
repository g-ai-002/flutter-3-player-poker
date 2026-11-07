/// 固定步长逻辑时钟：把渲染帧的可变 dt 累积成固定频率的逻辑步。
///
/// 逻辑速率与渲染帧率解耦：30Hz 更省电，120Hz 在高刷屏上更顺滑。
/// 单帧最多补 4 步，追不上的时间直接丢弃，避免一次掉帧后连续补帧。
class LogicClock {
  LogicClock({int rate = defaultRate})
    : _rate = supportedRates.contains(rate) ? rate : defaultRate;

  static const int defaultRate = 60;
  static const List<int> supportedRates = [30, 60, 120];
  static const int _maxStepsPerFrame = 4;

  int _rate;
  double _accumulator = 0;

  int get rate => _rate;

  set rate(int value) {
    final next = supportedRates.contains(value) ? value : defaultRate;
    if (next == _rate) return;
    _rate = next;
    _accumulator = 0;
  }

  /// 单个逻辑步的时长（秒）。
  double get step => 1 / _rate;

  /// 返回本帧应执行的逻辑步数，并消费对应的时间。
  int advance(double dt) {
    if (dt <= 0) return 0;
    _accumulator += dt;
    var steps = 0;
    while (_accumulator >= step && steps < _maxStepsPerFrame) {
      _accumulator -= step;
      steps++;
    }
    if (steps == _maxStepsPerFrame) _accumulator = 0;
    return steps;
  }
}
