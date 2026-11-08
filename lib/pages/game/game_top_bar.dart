import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../rules_page.dart';
import 'game_layout.dart';
import 'table_area.dart';

/// 悬浮顶栏：返回、底牌、倍数 / 明牌与更多菜单。
///
/// 整条顶栏悬浮在牌桌上方，牌桌只让出 [height] 的固定高度，
/// 记牌器与提示层都挂在它的下方，因此不会挤压牌桌或推挤手牌。
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.onBack,
    required this.onRestart,
    required this.counterOpen,
    required this.onToggleCounter,
  });

  /// 顶栏固定高度，牌桌页据此预留顶部空间。
  static const double height = GameLayout.topBarHeight;

  final VoidCallback onBack;
  final VoidCallback onRestart;

  /// 记牌器浮层是否常驻显示。
  final bool counterOpen;
  final VoidCallback onToggleCounter;

  static const TextStyle _menuText = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final engine = provider.engine;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < GameLayout.narrowWidth;
          final multiplier = narrow
              ? '×${engine.multiplier}'
              : engine.revealed
              ? '明牌 · ×${engine.multiplier}'
              : '底分 ${engine.baseScore} · ×${engine.multiplier}';
          return Row(
            children: [
              _cluster(Alignment.centerLeft, [
                _GlassIcon(
                  icon: Icons.arrow_back_ios_new,
                  tooltip: '返回',
                  onPressed: onBack,
                ),
                if (!narrow) ...[
                  const SizedBox(width: 8),
                  Text(
                    '斗地主',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      shadows: const [
                        Shadow(color: Color(0x66000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ],
              ]),
              BottomCardsBar(engine: engine, compact: narrow),
              const SizedBox(width: 8),
              _cluster(Alignment.centerRight, [
                _InfoChip(text: multiplier, maxWidth: narrow ? 84 : 190),
                const SizedBox(width: 4),
                _GlassIcon(
                  tooltip: counterOpen ? '隐藏记牌器' : '记牌器',
                  icon: counterOpen
                      ? Icons.visibility
                      : Icons.visibility_outlined,
                  onPressed: onToggleCounter,
                  active: counterOpen,
                ),
                _menu(context),
              ]),
            ],
          );
        },
      ),
    );
  }

  /// 顶栏两侧的信息位：可用宽度不足时整体缩放，底牌胶囊始终居中。
  Widget _cluster(Alignment alignment, List<Widget> children) => Expanded(
    child: Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );

  Widget _menu(BuildContext context) {
    void go(String value) {
      if (value == 'restart') onRestart();
      if (value == 'leave') onBack();
      if (value == 'rules') {
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const RulesPage()));
      }
    }

    return PopupMenuButton<String>(
      color: const Color(0xFF163526),
      padding: EdgeInsets.zero,
      tooltip: '更多',
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      iconSize: 20,
      icon: const Icon(Icons.more_horiz, color: Colors.white70),
      onSelected: go,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'restart',
          child: Text('重新开始', style: _menuText),
        ),
        PopupMenuItem(
          value: 'rules',
          child: Text('玩法说明', style: _menuText),
        ),
        PopupMenuItem(
          value: 'leave',
          child: Text('返回主页', style: _menuText),
        ),
      ],
    );
  }
}

/// 顶栏上的圆形半透明按钮，压在牌桌绒面上也不会糊成一团。
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: active ? 0.34 : 0.24),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 17,
              color: active ? kGoldSoft : Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

/// 倍数 / 明牌胶囊：顶栏右侧唯一的信息位。
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withValues(alpha: 0.35)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            color: kGoldSoft,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
