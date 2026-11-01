import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/table_overlay.dart';
import '../hand_record_page.dart';

/// 叫分浮层：轮到人类玩家时覆盖牌桌。
class BidOverlay extends StatelessWidget {
  const BidOverlay({super.key, required this.provider, required this.onLeave});

  final GameProvider provider;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final highest = provider.engine.highestBid;
    return TableOverlay(
      onLeave: onLeave,
      child: TablePanel(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '轮到你叫分',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              highest == 0 ? '尚无人叫分，叫分即底分' : '当前最高 $highest 分',
              style: TextStyle(
                color: kGoldSoft.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '叫 3 分直接成为地主；叫分最高者拿走 3 张底牌，以一敌二。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => provider.bid(0),
                    style: tableGhostButtonStyle(),
                    child: const Text('不叫'),
                  ),
                ),
                for (final score in const [1, 2, 3]) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton(
                      onPressed: score > highest
                          ? () => provider.bid(score)
                          : null,
                      style: goldButtonStyle(padding: EdgeInsets.zero),
                      child: Text(
                        '$score 分',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 加倍浮层：地主先选，随后两名农民依次选择。
class DoubleOverlay extends StatelessWidget {
  const DoubleOverlay({
    super.key,
    required this.provider,
    required this.onLeave,
  });

  final GameProvider provider;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final engine = provider.engine;
    final isLandlord = engine.landlord == 0;
    return TableOverlay(
      onLeave: onLeave,
      child: TablePanel(
        maxWidth: 330,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '是否加倍？',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '底分 ${engine.baseScore} · 当前倍数 ×${engine.multiplier}\n'
              '加倍后本局倍数再 ×2，胜负得分同步翻倍。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.7,
              ),
            ),
            if (isLandlord) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: provider.canReveal ? provider.revealHand : null,
                  style: tableGhostButtonStyle(
                    enabled: provider.canReveal,
                    foreground: kGoldSoft,
                  ),
                  icon: Icon(
                    provider.canReveal
                        ? Icons.visibility_outlined
                        : Icons.check_circle_outline,
                    size: 16,
                  ),
                  label: Text(
                    provider.canReveal ? '明牌 ×2（亮出全部手牌）' : '已明牌 · 倍数 ×2',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => provider.doubleUp(false),
                    style: tableGhostButtonStyle(),
                    child: const Text('不加倍'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => provider.doubleUp(true),
                    style: goldButtonStyle(),
                    child: const Text('加倍'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 结算浮层：胜负、倍数、本局得分与再来一局。
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.provider,
    required this.onLeave,
    required this.onRestart,
  });

  final GameProvider provider;
  final VoidCallback onLeave;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final result = provider.result;
    if (result == null) return const SizedBox.shrink();
    final won = result.humanWon(provider.humanIsLandlord);
    final score = result.scores[0];
    final tags = <String>[
      provider.humanIsLandlord ? '地主' : '农民',
      if (result.spring) '春天',
      if (result.antiSpring) '反春天',
    ];
    return TableOverlay(
      onLeave: onLeave,
      barrierOpacity: 0.58,
      showClose: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 24,
        ),
        child: SingleChildScrollView(
          child: TablePanel(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            radius: 20,
            gradient: const LinearGradient(
              colors: [Color(0xFF1B3C29), Color(0xFF0E2419)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.emoji_events_rounded : Icons.handshake_outlined,
                  size: 44,
                  color: won ? kGold : Colors.white54,
                ),
                const SizedBox(height: 8),
                Text(
                  won ? '胜利' : '惜败',
                  style: TextStyle(
                    color: won ? kGoldSoft : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${tags.join(' · ')} · 倍数 ×${result.multiplier}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '本局得分',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${score >= 0 ? '+' : ''}$score',
                        style: TextStyle(
                          color: score >= 0
                              ? kGoldSoft
                              : const Color(0xFFE08A7A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ScoreBoard(provider: provider),
                if (provider.lastRecord != null) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HandRecordPage(record: provider.lastRecord!),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: kGoldSoft,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('查看本局牌谱'),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onLeave,
                        style: tableGhostButtonStyle(
                          foreground: Colors.white.withValues(alpha: 0.7),
                        ),
                        child: const Text('返回主页'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onRestart,
                        style: goldButtonStyle(),
                        child: const Text('再来一局'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 三家本局得分：地主与两名农民对照展示。
class ScoreBoard extends StatelessWidget {
  const ScoreBoard({super.key, required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    final result = provider.result;
    if (result == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final player in provider.engine.players)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${player.name}${player.isLandlord ? ' · 地主' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.scores[player.id] >= 0 ? '+' : ''}'
                    '${result.scores[player.id]}',
                    style: TextStyle(
                      color: result.scores[player.id] >= 0
                          ? kGoldSoft
                          : const Color(0xFFE08A7A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
