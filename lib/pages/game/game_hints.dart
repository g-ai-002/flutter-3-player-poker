import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

/// 牌桌网格四周的悬浮提示层：轮次、上一手、残局提醒与临时反馈。
///
/// 窄屏把四条槽位叠在网格上方；宽屏把残局、动作与反馈分列到网格左右两侧，
/// 中间只留轮次胶囊。整层 [IgnorePointer] 且不参与布局，提示出现或消失
/// 既不会推动牌桌、手牌与操作条，也不会挡住宿主的手势。
class GameHints extends StatelessWidget {
  const GameHints({
    super.key,
    required this.provider,
    this.showSelection = false,
    this.sides = false,
  });

  final GameProvider provider;

  /// 窄屏操作条放不下牌型说明时，改由提示展示当前选牌的牌型。
  final bool showSelection;

  /// 宽度足够时把提示分列网格左右，避免全部堆在网格上方。
  final bool sides;

  @override
  Widget build(BuildContext context) {
    // 选牌变化只刷新提示层，牌桌与座位不参与这次重建。
    return ValueListenableBuilder<Set<int>>(
      valueListenable: provider.selection,
      builder: (context, _, _) => _buildHints(),
    );
  }

  Widget _buildHints() {
    final engine = provider.engine;
    final landlord = engine.landlord;
    final selection = provider.selectedCards.isEmpty
        ? null
        : provider.selectedCombo?.description ?? '牌型不合法';
    final action = showSelection && selection != null
        ? selection
        : engine.lastActionText;
    final alert =
        provider.endgameAlert ??
        (engine.revealed && landlord != null && landlord != 0
            ? '地主已明牌 · 点击其座位查看手牌'
            : null);
    final feedback = provider.feedback;

    return IgnorePointer(
      child: sides
          ? _sides(provider.turnHint, action, alert, feedback)
          : _stacked(provider.turnHint, action, alert, feedback),
    );
  }

  /// 窄屏 / 竖屏：四条固定高度的槽位纵向叠在网格上方。
  Widget _stacked(
    String turn,
    String? action,
    String? alert,
    String? feedback,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slot(24, TurnChip(text: turn)),
            _slot(
              18,
              _caption(action, 10, Colors.white.withValues(alpha: 0.5)),
            ),
            _slot(16, _caption(alert, 9.5, kGoldSoft.withValues(alpha: 0.8))),
            _slot(34, _feedback(feedback)),
          ],
        ),
      ),
    );
  }

  /// 宽屏：轮次与上一手在网格正上方居中，残局提醒在左，临时反馈在右。
  Widget _sides(String turn, String? action, String? alert, String? feedback) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideWidth = constraints.maxWidth * 0.17;
        final progress = _caption(
          action,
          9.5,
          Colors.white.withValues(alpha: 0.55),
        );
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.58,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TurnChip(text: turn),
                      if (progress != null) ...[
                        const SizedBox(height: 2),
                        progress,
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _edge(
              sideWidth,
              Alignment.centerLeft,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ?_caption(alert, 10, kGoldSoft.withValues(alpha: 0.85)),
              ],
            ),
            _edge(
              sideWidth,
              Alignment.centerRight,
              right: true,
              children: [_feedback(feedback, maxLines: 3)],
            ),
          ],
        );
      },
    );
  }

  /// 网格左右两侧的提示位：贴边显示，宽度按屏幕比例收敛。
  Widget _edge(
    double width,
    Alignment alignment, {
    required List<Widget> children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    bool right = false,
  }) {
    return Positioned(
      left: right ? null : 0,
      right: right ? 0 : null,
      top: 0,
      bottom: 0,
      width: width,
      child: Align(
        alignment: alignment,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        ),
      ),
    );
  }

  Widget _feedback(String? feedback, {int maxLines = 1}) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 160),
    child: feedback == null
        ? const SizedBox.shrink()
        : FeedbackToast(
            key: const ValueKey('feedback'),
            text: feedback,
            maxLines: maxLines,
          ),
  );

  /// 固定高度的提示槽位：内容为空时也占位，避免牌桌布局跳动。
  Widget _slot(double height, Widget? child) => SizedBox(
    height: height,
    child: child == null ? null : Center(child: child),
  );

  Widget? _caption(String? text, double size, Color color, {int maxLines = 1}) {
    if (text == null) return null;
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: size, height: 1.35),
    );
  }
}

/// 轮次提示胶囊。
class TurnChip extends StatelessWidget {
  const TurnChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

/// 临时反馈：非法操作、超时自动出牌等，悬浮在牌桌四周。
class FeedbackToast extends StatelessWidget {
  const FeedbackToast({super.key, required this.text, this.maxLines = 1});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xF0182B20),
        borderRadius: BorderRadius.circular(20),
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
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
      ),
    );
  }
}
