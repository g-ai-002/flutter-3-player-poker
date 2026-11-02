import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../game/card_counter.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/card_counter_panel.dart';
import '../rules_page.dart';

/// 牌桌顶栏：返回、地主信息、当前倍数与更多菜单。
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.onBack,
    required this.onRestart,
    this.compact = false,
  });

  final VoidCallback onBack;
  final VoidCallback onRestart;
  final bool compact;

  static const TextStyle _menuText = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// 记牌器：顶部浮层展示两家剩余的牌，不遮挡手牌与操作条。
  Future<void> _showCounter(BuildContext context, GameProvider provider) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭记牌器',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 56,
            left: 14,
            right: 14,
          ),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12301F),
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
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, size: 18),
                          color: Colors.white.withValues(alpha: 0.7),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ListenableBuilder(
                      listenable: provider,
                      builder: (context, _) => CardCounterPanel(
                        counts: CardCounter.remaining(provider.engine),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final landlord = provider.engine.landlord;
    final landlordName = landlord == null
        ? '未定'
        : provider.engine.players[landlord].name;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: Colors.white.withValues(alpha: 0.85),
            tooltip: '返回',
            constraints: compact
                ? const BoxConstraints.tightFor(width: 40, height: 40)
                : null,
            padding: compact ? EdgeInsets.zero : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '斗地主',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '地主：$landlordName · 底分 ${provider.engine.baseScore}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '记牌器',
            onPressed: () => _showCounter(context, provider),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            color: Colors.white.withValues(alpha: 0.7),
            constraints: compact
                ? const BoxConstraints.tightFor(width: 34, height: 40)
                : null,
            padding: compact ? EdgeInsets.zero : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGold.withValues(alpha: 0.35)),
            ),
            child: Text(
              provider.engine.revealed
                  ? '明牌 · ×${provider.engine.multiplier}'
                  : '倍数 ×${provider.engine.multiplier}',
              style: const TextStyle(
                color: kGoldSoft,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF163526),
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
            onSelected: (value) {
              if (value == 'restart') onRestart();
              if (value == 'rules') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RulesPage()),
                );
              }
              if (value == 'leave') onBack();
            },
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
          ),
        ],
      ),
    );
  }
}
