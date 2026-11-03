import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../theme/app_theme.dart';
import 'turn_countdown.dart';

/// AI 座位：头像、身份、剩余手牌与状态气泡。
class SeatPanel extends StatelessWidget {
  const SeatPanel({
    super.key,
    required this.player,
    required this.isCurrent,
    required this.thinking,
    this.phase = GamePhase.playing,
    this.revealed = false,
    this.onTap,
    this.countdown,
    this.compact = false,
  });

  final PlayerState player;
  final bool isCurrent;
  final bool thinking;
  final GamePhase phase;

  /// 该玩家已明牌：显示标记，配合 [onTap] 可查看亮出的手牌。
  final bool revealed;
  final VoidCallback? onTap;

  /// 出牌阶段的回合倒计时；只在该玩家回合展示。
  final ValueListenable<int>? countdown;

  /// 手机横屏等矮屏使用单行紧凑样式，把高度留给放大的出牌区。
  final bool compact;

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
    if (compact) return _buildCompact(status);
    return GestureDetector(
      onTap: revealed ? onTap : null,
      child: Container(
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
                  const Positioned(
                    right: -12,
                    top: -6,
                    child: _SeatBadge(
                      text: '地主',
                      background: kGold,
                      foreground: Color(0xFF3A2606),
                      borderColor: Color(0xFF5A3D0C),
                    ),
                  ),
                if (revealed)
                  Positioned(
                    left: -12,
                    top: -6,
                    child: _SeatBadge(
                      text: '明牌',
                      background: const Color(0xFF2C4A38),
                      foreground: kGoldSoft,
                      borderColor: kGold.withValues(alpha: 0.7),
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
            if (isCurrent &&
                phase == GamePhase.playing &&
                countdown != null) ...[
              TurnCountdown(seconds: countdown!, compact: true),
              const SizedBox(height: 2),
            ],
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
      ),
    );
  }

  /// 矮屏单行座位：头像 + 名字 / 手牌数 + 状态，高度约 34。
  Widget _buildCompact(String status) {
    return GestureDetector(
      onTap: revealed ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? kGold.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08),
            width: isCurrent ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: player.isLandlord
                      ? const [Color(0xFFE0B45F), Color(0xFF9A6B20)]
                      : const [Color(0xFF3E7A5B), Color(0xFF1B3E2B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Center(
                child: Text(
                  player.name.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (player.isLandlord) ...[
                      const SizedBox(width: 3),
                      const _SeatBadge(
                        text: '地主',
                        background: kGold,
                        foreground: Color(0xFF3A2606),
                        borderColor: Color(0xFF5A3D0C),
                      ),
                    ],
                    if (revealed) ...[
                      const SizedBox(width: 3),
                      const _SeatBadge(
                        text: '明牌',
                        background: Color(0xFF2C4A38),
                        foreground: kGoldSoft,
                        borderColor: kGold,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${player.hand.length} 张 · $status',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9,
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

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({
    required this.text,
    required this.background,
    required this.foreground,
    required this.borderColor,
  });

  final String text;
  final Color background;
  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
