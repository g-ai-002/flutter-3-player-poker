/// 牌桌页的固定几何。
///
/// 顶栏与底部操作 dock 都按这里的尺寸占位，提示层只在悬浮层里出现，
/// 因此提示、选牌与阶段切换都不会改变主界面布局。
abstract final class GameLayout {
  /// 悬浮顶栏高度：牌桌页让出这块高度，座位不会被顶栏压住。
  static const double topBarHeight = 40;

  /// 底部操作 dock 高度：叫分、加倍阶段也保留同一高度。
  static const double actionBarHeight = 40;

  /// 小于该宽度时顶栏收起标题、操作条收起牌型说明，改由悬浮提示展示。
  static const double narrowWidth = 520;

  /// 宽度达到该值时提示分列网格左右两侧：两家出牌区外侧还有余量。
  static const double sideHintsWidth = 720;

  /// 横屏提示带：网格上方居中放轮次胶囊与上一手进度，其余提示放到左右两侧。
  static const double sideHintBand = 44;

  /// 竖屏 / 窄屏提示带：四条固定槽位叠在网格上方。
  static const double stackedHintBand = 92;

  /// 牌桌网格上方要预留的提示带高度。
  static double hintBand({required bool sides}) =>
      sides ? sideHintBand : stackedHintBand;

  /// 是否把提示分列到网格左右两侧。
  static bool sideHints(double width) => width >= sideHintsWidth;
}
