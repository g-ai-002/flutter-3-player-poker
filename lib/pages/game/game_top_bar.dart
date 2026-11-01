import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
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
                  '地主：$landlordName',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGold.withValues(alpha: 0.35)),
            ),
            child: Text(
              '倍数 ×${provider.engine.multiplier}',
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
              PopupMenuItem(value: 'restart', child: Text('重新开始')),
              PopupMenuItem(value: 'rules', child: Text('玩法说明')),
              PopupMenuItem(value: 'leave', child: Text('返回主页')),
            ],
          ),
        ],
      ),
    );
  }
}
