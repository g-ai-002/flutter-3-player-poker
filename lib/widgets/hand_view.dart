import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/playing_card.dart';
import 'playing_card_view.dart';

/// 扇形展开的手牌：按可用宽度自动压缩叠放间距，选中牌上抬。
class HandView extends StatelessWidget {
  const HandView({
    super.key,
    required this.cards,
    required this.selectedIds,
    required this.onTap,
    this.enabled = true,
    this.maxCardWidth,
  });

  final List<PlayingCard> cards;
  final Set<int> selectedIds;
  final ValueChanged<int> onTap;
  final bool enabled;
  final double? maxCardWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (cards.isEmpty) return const SizedBox(height: 84);
        final width = constraints.maxWidth;
        final baseWidth =
            maxCardWidth ?? (width > 900 ? 66.0 : (width > 600 ? 60.0 : 52.0));
        final cardWidth = math.min(baseWidth, width / 3.1);
        final spacing = cards.length == 1
            ? 0.0
            : math.min(
                cardWidth * 0.62,
                math.max(11.0, (width - cardWidth) / (cards.length - 1)),
              );
        final height = cardWidth * 1.4 + 18;
        final totalWidth = cardWidth + spacing * (cards.length - 1);
        return SizedBox(
          height: height,
          child: Align(
            child: SizedBox(
              width: totalWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < cards.length; i++)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 120),
                      left: i * spacing,
                      bottom: selectedIds.contains(cards[i].id) ? 16 : 0,
                      child: GestureDetector(
                        key: ValueKey('hand-card-${cards[i].id}'),
                        onTap: enabled ? () => onTap(cards[i].id) : null,
                        child: PlayingCardView(
                          card: cards[i],
                          width: cardWidth,
                          selected: selectedIds.contains(cards[i].id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
