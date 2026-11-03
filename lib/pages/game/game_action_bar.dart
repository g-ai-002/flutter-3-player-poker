import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hand_view.dart';
import '../../widgets/turn_countdown.dart';

/// 底部操作条：牌型说明在左，提示 / 不出 / 出牌三个按钮居中。
class GameActionBar extends StatelessWidget {
  const GameActionBar({super.key, required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    final selected = provider.selectedCombo;
    final label = provider.selectedCards.isEmpty
        ? '请选择要出的牌'
        : selected?.description ?? '牌型不合法';
    final empty = provider.selectedCards.isEmpty;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: empty ? Colors.white.withValues(alpha: 0.55) : kGoldSoft,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          label: '提示',
          onPressed: provider.isHumanTurn ? provider.hint : null,
          outlined: true,
        ),
        const SizedBox(width: 6),
        _ActionButton(
          label: '不出',
          onPressed: provider.canPass ? provider.pass : null,
          outlined: true,
        ),
        const SizedBox(width: 6),
        _ActionButton(
          label: '出牌',
          onPressed: provider.canPlay ? provider.playSelected : null,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 窄屏放不下「倒计时 + 说明 + 按钮」一行：说明单独占一行。
          if (constraints.maxWidth < 520) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Center(child: labelText),
                ),
                const SizedBox(height: 2),
                SizedBox(height: 38, child: buttons),
              ],
            );
          }
          return SizedBox(
            height: 38,
            child: Row(
              children: [
                // 左侧留白与右侧 Spacer 对称，保证三个按钮始终居中。
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (provider.isHumanTurn) ...[
                          TurnCountdown(
                            seconds: provider.turnSecondsLeft,
                            compact: true,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(child: labelText),
                        const SizedBox(width: 6),
                        Text(
                          '${provider.humanHand.length} 张',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                buttons,
                const Spacer(),
              ],
            ),
          );
        },
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
    final button = outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: tableGhostButtonStyle(
              enabled: onPressed != null,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foreground: Colors.white,
            ),
            child: Text(label),
          )
        : FilledButton(
            onPressed: onPressed,
            style: goldButtonStyle(shape: const StadiumBorder()),
            child: Text(label),
          );
    return SizedBox(height: 38, child: button);
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
      child: RepaintBoundary(
        child: HandView(
          cards: provider.humanHand,
          selectedIds: provider.selectedIds,
          enabled: provider.isHumanTurn,
          onTap: provider.toggleCard,
          onSelectionChanged: provider.setSelection,
          maxCardWidth: compact ? 44 : null,
        ),
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
