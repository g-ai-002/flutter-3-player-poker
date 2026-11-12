import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hand_view.dart';
import '../../widgets/turn_countdown.dart';
import 'game_layout.dart';

/// 底部操作 dock：提示 / 不出 / 出牌三个按钮居中，始终占据固定高度。
///
/// 叫分、加倍阶段也保留同高度的空 dock，出牌阶段的倒计时与牌型说明只在
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
    // 只有选牌变化时才重建操作条，点牌不会带动牌桌与手牌整页重建。
    return ValueListenableBuilder<Set<int>>(
      valueListenable: provider.selection,
      builder: (context, _, _) => _playing(context),
    );
  }

  Widget _playing(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < GameLayout.narrowWidth;
    final empty = provider.selectedCards.isEmpty;
    final label = empty
        ? '请选择要出的牌'
        : provider.selectedCombo?.description ?? '牌型不合法';
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
          child: Row(
            children: [
              _side(
                Alignment.centerRight,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.isHumanTurn) ...[
                      TurnCountdown(
                        seconds: provider.turnSecondsLeft,
                        compact: true,
                      ),
                      if (!narrow) const SizedBox(width: 8),
                    ],
                    if (!narrow)
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: empty
                              ? Colors.white.withValues(alpha: 0.55)
                              : kGoldSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buttons(),
              _side(
                Alignment.centerLeft,
                Padding(
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
            ],
          ),
        ),
      ),
    );
  }

  /// 三个操作按钮：提示与不出为描边款，出牌为主按钮。
  Widget _buttons() {
    Widget ghost(String label, VoidCallback? onPressed) =>
        _ActionButton(label: label, onPressed: onPressed, outlined: true);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ghost('提示', provider.isHumanTurn ? provider.hint : null),
        const SizedBox(width: 6),
        ghost('不出', provider.canPass ? provider.pass : null),
        const SizedBox(width: 6),
        _ActionButton(
          label: '出牌',
          onPressed: provider.canPlay ? provider.playSelected : null,
        ),
      ],
    );
  }

  /// 两侧信息位：各自占一半可用宽度，放不下时整体缩放而不是挤压按钮。
  Widget _side(Alignment alignment, Widget child) => Expanded(
    child: Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: child,
      ),
    ),
  );
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
    return SizedBox(
      height: 38,
      child: outlined
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
      child: RepaintBoundary(
        child: ValueListenableBuilder<Set<int>>(
          valueListenable: provider.selection,
          builder: (context, selectedIds, _) => HandView(
            cards: provider.humanHand,
            selectedIds: selectedIds,
            enabled: provider.isHumanTurn,
            onTap: provider.toggleCard,
            onSelectionChanged: provider.setSelection,
            maxCardWidth: compact ? 44 : null,
          ),
        ),
      ),
    );
  }
}
