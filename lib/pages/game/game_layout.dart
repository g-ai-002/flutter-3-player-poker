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
}
