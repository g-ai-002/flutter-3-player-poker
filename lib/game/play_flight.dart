import 'dart:math' as math;
import 'dart:ui';

/// 出牌飞行动画的统一节拍与出牌区几何。
///
/// 牌桌层（Flame）、出牌区（Flutter）与对局状态（牌堆何时亮出）共用这里的规则，
/// 飞出的牌在数量、尺寸与落点上都与最终摆到牌桌上的牌一致。
abstract final class PlayFlight {
  /// 相邻两张牌的起飞间隔（秒）。
  static const double stagger = 0.035;

  /// 单张牌的飞行时长（秒）。
  static const double duration = 0.32;

  /// 牌面宽高比，与手牌、出牌区保持一致。
  static const double cardAspect = 1.4;

  /// 一组牌的动画总时长（秒）。
  static double total(int count) =>
      count <= 0 ? 0 : duration + stagger * (count - 1);

  /// 牌堆要等飞牌落定后才亮出，多留 32 毫秒避开最后几帧。
  static Duration revealDelay(int count) =>
      Duration(milliseconds: (total(count) * 1000).round() + 32);

  /// 出牌区单张牌的叠放间距：与 `PlayedCardsView` 使用同一套规则。
  static double spacing({
    required int count,
    required double cardWidth,
    required double maxWidth,
  }) {
    if (count <= 1) return 0;
    return math.min(
      cardWidth * 0.62,
      math.max(8.0, (maxWidth - cardWidth) / (count - 1)),
    );
  }
}

/// 一家在牌桌上的几何：出牌区牌堆中心、单张牌的实际显示尺寸、叠放可用宽度、
/// 倾斜角度，以及飞牌起飞的座位点。
class PlayerTarget {
  const PlayerTarget({
    required this.center,
    required this.cardSize,
    required this.maxWidth,
    this.angle = 0,
    this.seat,
  });

  /// 牌堆中心相对牌桌的坐标（0..1）。
  final Offset center;

  /// 单张牌在牌桌上的实际显示尺寸（已包含牌桌的缩放）。
  final Size cardSize;

  /// 出牌区叠放的可用宽度。
  final double maxWidth;

  /// 牌堆的倾斜角度：左右两家朝各自座位倾斜。
  final double angle;

  /// 该家座位（AI 为头像、人类玩家为手牌）相对牌桌的坐标（0..1）。
  final Offset? seat;

  @override
  bool operator ==(Object other) =>
      other is PlayerTarget &&
      other.center == center &&
      other.cardSize == cardSize &&
      other.maxWidth == maxWidth &&
      other.angle == angle &&
      other.seat == seat;

  @override
  int get hashCode => Object.hash(center, cardSize, maxWidth, angle, seat);
}
