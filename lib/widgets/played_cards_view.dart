import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/combo.dart';
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
    this.maxWidth = 240,
    this.cardWidth = 36,
    this.showCombo = true,
  });

  final List<PlayingCard> cards;
  final Combo? combo;
  final bool passed;
  final double maxWidth;

  /// 单张牌宽；牌桌中央比侧栏需要更大的牌面。
  final double cardWidth;

  /// 是否展示牌型名称，中央出牌区可按布局需要隐藏。
  final bool showCombo;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      if (!passed) return const SizedBox(height: 44);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCombo && combo != null)
          Text(
            combo!.description,
            style: const TextStyle(
              color: kGoldSoft,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (showCombo && combo != null) const SizedBox(height: 3),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = cards.length;
            final width = math.min(maxWidth, constraints.maxWidth);
            final spacing = count <= 1
                ? 0.0
                : math.min(
                    cardWidth * 0.62,
                    math.max(8.0, (width - cardWidth) / (count - 1)),
                  );
            // 长牌型（如带翅膀的飞机）在窄屏上按比例缩小，避免横向溢出。
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: cardWidth + spacing * (count - 1),
                height: cardWidth * 1.4,
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
    );
  }
}
