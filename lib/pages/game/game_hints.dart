import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

/// 牌桌四周的悬浮提示层：轮次、上一手、明牌提醒与临时反馈。
///
/// 每一行都占固定高度，整层 [IgnorePointer]，提示出现或消失既不会推动牌桌、
/// 手牌与操作条，也不会挡住宿主的手势。
class GameHints extends StatelessWidget {
  const GameHints({
    super.key,
    required this.provider,
    this.showSelection = false,
  });

  final GameProvider provider;

  /// 窄屏操作条放不下牌型说明时，改由顶部提示展示当前选牌的牌型。
  final bool showSelection;

  @override
  Widget build(BuildContext context) {
    final engine = provider.engine;
    final selection = provider.selectedCards.isEmpty
        ? null
        : provider.selectedCombo?.description ?? '牌型不合法';
    final action = showSelection && selection != null
        ? selection
        : engine.lastActionText;
    final landlord = engine.landlord;
    final alert =
        provider.endgameAlert ??
        (engine.revealed && landlord != null && landlord != 0
            ? '地主已明牌 · 点击其座位查看手牌'
            : null);
    final feedback = provider.feedback;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _slot(24, TurnChip(text: provider.turnHint)),
              _slot(
                18,
                _caption(action, 10, Colors.white.withValues(alpha: 0.5)),
              ),
              _slot(16, _caption(alert, 9.5, kGoldSoft.withValues(alpha: 0.8))),
              _slot(
                32,
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: feedback == null
                      ? const SizedBox.shrink()
                      : FeedbackToast(
                          key: const ValueKey('feedback'),
                          text: feedback,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 固定高度的提示槽位：内容为空时也占位，避免牌桌布局跳动。
  Widget _slot(double height, Widget? child) => SizedBox(
    height: height,
    child: child == null ? null : Center(child: child),
  );

  Widget? _caption(String? text, double size, Color color) {
    if (text == null) return null;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: size),
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

/// 临时反馈：非法操作、超时自动出牌等，悬浮在牌桌上方。
class FeedbackToast extends StatelessWidget {
  const FeedbackToast({super.key, required this.text});

  final String text;

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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
