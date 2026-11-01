import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hand_view.dart';

/// 底部操作条：选中牌型说明、提示 / 不出 / 出牌。
class GameActionBar extends StatelessWidget {
  const GameActionBar({super.key, required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    final selected = provider.selectedCombo;
    final label = provider.selectedCards.isEmpty
        ? '请选择要出的牌'
        : selected?.description ?? '牌型不合法';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: provider.selectedCards.isEmpty
                        ? Colors.white.withValues(alpha: 0.55)
                        : kGoldSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.humanIsLandlord
                      ? '地主 · 剩余 ${provider.humanHand.length} 张'
                      : '农民 · 剩余 ${provider.humanHand.length} 张',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _ActionButton(
            label: '提示',
            onPressed: provider.isHumanTurn ? provider.hint : null,
            outlined: true,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            label: '不出',
            onPressed: provider.canPass ? provider.pass : null,
            outlined: true,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            label: '出牌',
            onPressed: provider.canPlay ? provider.playSelected : null,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        height: 38,
        child: OutlinedButton(
          onPressed: onPressed,
          style: tableGhostButtonStyle(
            enabled: onPressed != null,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            fontSize: 12,
            foreground: Colors.white,
          ),
          child: Text(label),
        ),
      );
    }
    return SizedBox(
      height: 38,
      child: FilledButton(
        onPressed: onPressed,
        style: goldButtonStyle(shape: const StadiumBorder()),
        child: Text(label),
      ),
    );
  }
}

/// 人类玩家手牌区：手机紧凑高度下使用更小的牌宽。
class HumanHandView extends StatelessWidget {
  const HumanHandView({
    super.key,
    required this.provider,
    this.compact = false,
  });

  final GameProvider provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 2, 12, compact ? 4 : 8),
      child: HandView(
        cards: provider.humanHand,
        selectedIds: provider.selectedIds,
        enabled: provider.isHumanTurn,
        onTap: provider.toggleCard,
        maxCardWidth: compact ? 44 : null,
      ),
    );
  }
}

/// 顶部轻提示：非法操作、无解提示等。
class FeedbackToast extends StatelessWidget {
  const FeedbackToast({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xF0182B20),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kGold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
