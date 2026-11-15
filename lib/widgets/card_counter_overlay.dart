import 'package:material_ui/material_ui.dart';

import '../game/card_counter.dart';
import '../theme/app_theme.dart';

/// 记牌器常驻浮层：贴在牌桌上方，不加遮罩，随时可看且不打断操作。
class CardCounterOverlay extends StatelessWidget {
  const CardCounterOverlay({
    super.key,
    required this.counts,
    required this.onClose,
  });

  /// 两家剩余的牌，按点数汇总。
  final Map<int, int> counts;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF12301F).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '记牌器 · 两家剩余',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭记牌器',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.white.withValues(alpha: 0.75),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
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
            ),
          ],
        ),
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
