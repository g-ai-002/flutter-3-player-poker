import 'package:flutter/material.dart';

import '../game/card_counter.dart';
import '../theme/app_theme.dart';

/// 记牌器面板：按点数展示两家对手还剩下的牌。
class CardCounterPanel extends StatelessWidget {
  const CardCounterPanel({super.key, required this.counts});

  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.22)),
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final rank in CardCounter.ranks)
            if ((counts[rank] ?? 0) > 0)
              _CounterChip(
                label: CardCounter.label(rank),
                count: counts[rank]!,
              ),
        ],
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label×$count',
        style: TextStyle(
          color: count == 1 ? kGoldSoft : Colors.white.withValues(alpha: 0.82),
          fontSize: 11,
          height: 1.35,
        ),
      ),
    );
  }
}
