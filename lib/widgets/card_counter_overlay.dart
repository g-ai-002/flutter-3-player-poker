import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'card_counter_panel.dart';

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
            CardCounterPanel(counts: counts),
          ],
        ),
      ),
    );
  }
}
