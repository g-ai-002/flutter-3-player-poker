import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/combo.dart';
import '../game/play_flight.dart';
import '../models/playing_card.dart';
import '../theme/app_theme.dart';
import 'playing_card_view.dart';

/// 出牌区：牌型标签 + 重叠排列的牌，空态显示「不出」。
class PlayedCardsView extends StatelessWidget {
  const PlayedCardsView({
    super.key,
    required this.cards,
    this.combo,
    this.passed = false,
    this.hidden = false,
    this.maxWidth = 240,
    this.cardWidth = 36,
  });

  final List<PlayingCard> cards;
  final Combo? combo;
  final bool passed;

  /// 飞牌动画进行中：牌堆照常排版但完全透明，动画落定的瞬间再亮出。
  ///
  /// 保持排版不变是为了让飞牌落点与牌桌牌面严丝合缝，不会在亮出时跳位。
  final bool hidden;

  final double maxWidth;

  /// 单张牌宽；牌桌中央比侧栏需要更大的牌面。
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      // 空出牌区也占住整列宽度，飞牌动画与三足鼎立布局都以它为准。
      if (!passed) {
        return SizedBox(
          width: maxWidth,
          height: cardWidth * PlayFlight.cardAspect,
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          '不出',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      );
    }

    return _visible(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (combo != null)
            Text(
              combo!.description,
              style: const TextStyle(
                color: kGoldSoft,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (combo != null) const SizedBox(height: 3),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = cards.length;
              final width = math.min(maxWidth, constraints.maxWidth);
              final spacing = PlayFlight.spacing(
                count: count,
                cardWidth: cardWidth,
                maxWidth: width,
              );
              // 长牌型（如带翅膀的飞机）在窄屏上按比例缩小，避免横向溢出。
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: cardWidth + spacing * (count - 1),
                  height: cardWidth * PlayFlight.cardAspect,
                  child: Stack(
                    children: [
                      for (var i = 0; i < count; i++)
                        Positioned(
                          left: i * spacing,
                          child: PlayingCardView(
                            card: cards[i],
                            width: cardWidth,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _visible(Widget pile) =>
      hidden ? Opacity(opacity: 0, child: pile) : pile;
}
