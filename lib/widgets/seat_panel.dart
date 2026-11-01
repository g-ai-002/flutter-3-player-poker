import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../theme/app_theme.dart';

/// AI 座位：头像、身份、剩余手牌与状态气泡。
class SeatPanel extends StatelessWidget {
  const SeatPanel({
    super.key,
    required this.player,
    required this.isCurrent,
    required this.thinking,
    this.phase = GamePhase.playing,
  });

  final PlayerState player;
  final bool isCurrent;
  final bool thinking;
  final GamePhase phase;

  String get _status {
    if (thinking) return '思考中…';
    if (player.lastPassed) return '不出';
    if (player.hand.isEmpty) return '已出完';
    if (!isCurrent) return '等待';
    return switch (phase) {
      GamePhase.bidding => '叫分中',
      GamePhase.doubling => '加倍中',
      GamePhase.playing => '出牌中',
      _ => '等待',
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? kGold.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 1.4 : 0.8,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: kGold.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: player.isLandlord
                        ? const [Color(0xFFE0B45F), Color(0xFF9A6B20)]
                        : const [Color(0xFF3E7A5B), Color(0xFF1B3E2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    player.name.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (player.isLandlord)
                Positioned(
                  right: -12,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: kGold,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF5A3D0C),
                        width: 0.6,
                      ),
                    ),
                    child: const Text(
                      '地主',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A2606),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            player.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.style_outlined,
                size: 12,
                color: Color(0xFFEBD6A4),
              ),
              const SizedBox(width: 3),
              Text(
                '${player.hand.length}',
                style: const TextStyle(
                  color: Color(0xFFEBD6A4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Container(
              key: ValueKey(status),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: status == '不出'
                    ? Colors.white.withValues(alpha: 0.08)
                    : kGold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status == '不出'
                      ? Colors.white.withValues(alpha: 0.65)
                      : kGoldSoft,
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
