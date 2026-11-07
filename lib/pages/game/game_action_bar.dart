import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hand_view.dart';
import '../../widgets/turn_countdown.dart';
import 'game_layout.dart';

/// 底部操作 dock：提示 / 不出 / 出牌三个按钮居中，始终占据固定高度。
///
/// 叫分、加倍阶段也保留同高度的空 dock，出牌阶段的提示与选牌文案只在
/// 左右两侧的信息位内变化，因此按钮、手牌与牌桌都不会发生位移。
class GameActionBar extends StatelessWidget {
  const GameActionBar({super.key, required this.provider});

  /// 操作条固定高度，牌桌页不需要再为它单独计算占位。
  static const double height = GameLayout.actionBarHeight;

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.phase != GamePhase.playing) {
      return const SizedBox(width: double.infinity, height: height);
    }
    final selected = provider.selectedCombo;
    final empty = provider.selectedCards.isEmpty;
    final label = empty ? '请选择要出的牌' : selected?.description ?? '牌型不合法';
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

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.2)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 窄屏放不下「倒计时 + 说明」：说明改由顶部悬浮提示展示。
              final narrow = constraints.maxWidth < GameLayout.narrowWidth;
              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (provider.isHumanTurn) ...[
                              TurnCountdown(
                                seconds: provider.turnSecondsLeft,
                                compact: true,
                              ),
                              if (!narrow) const SizedBox(width: 8),
                            ],
                            if (!narrow) labelText,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  buttons,
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(
                            '${provider.humanHand.length} 张',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
