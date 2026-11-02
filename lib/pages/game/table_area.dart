import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/played_cards_view.dart';
import '../../widgets/playing_card_view.dart';
import '../../widgets/seat_panel.dart';

/// 牌桌顶部的底牌条：开局背面朝上，地主确定后亮出。
class BottomCardsBar extends StatelessWidget {
  const BottomCardsBar({super.key, required this.engine, this.compact = false});

  final DdzEngine engine;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final revealed = engine.landlord != null;
    final width = compact ? 27.0 : 31.0;
    return SizedBox(
      height: compact ? 42 : 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '底牌',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          for (final card in engine.bottomCards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: PlayingCardView(
                card: card,
                width: width,
                faceDown: !revealed,
              ),
            ),
          if (engine.bottomCards.isEmpty)
            Text(
              '待发牌',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

/// 牌桌中央区域：三家最近一手牌集中在中央，两侧只保留座位信息。
class GameTableArea extends StatelessWidget {
  const GameTableArea({
    super.key,
    required this.provider,
    required this.landscape,
    this.compact = false,
  });

  final GameProvider provider;
  final bool landscape;
  final bool compact;

  /// 明牌手牌浮层：地主亮牌后，农民可随时查看。
  void _showRevealedHand(BuildContext context, PlayerState player) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${player.name} · 明牌'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final card in player.hand)
                  PlayingCardView(card: card, width: 36),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  SeatPanel _seatPanel(
    BuildContext context,
    GameProvider provider,
    PlayerState player,
  ) {
    final revealed =
        provider.engine.revealed && provider.engine.landlord == player.id;
    return SeatPanel(
      player: player,
      isCurrent: provider.engine.currentPlayer == player.id,
      thinking: provider.thinkingPlayer == player.id,
      phase: provider.engine.phase,
      revealed: revealed,
      countdown: provider.turnSecondsLeft,
      onTap: revealed ? () => _showRevealedHand(context, player) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = provider.engine;
    final left = engine.players[2];
    final right = engine.players[1];
    if (landscape) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _SeatColumn(
              seat: _seatPanel(context, provider, left),
              compact: compact,
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: PlayField(provider: provider, landscape: true),
                  ),
                ),
                StatusInfo(provider: provider),
                const SizedBox(height: 2),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _SeatColumn(
              seat: _seatPanel(context, provider, right),
              compact: compact,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(
          height: compact ? 104 : 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 2),
                child: _seatPanel(context, provider, left),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: _seatPanel(context, provider, right),
              ),
            ],
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: PlayField(provider: provider, landscape: false),
          ),
        ),
        StatusInfo(provider: provider),
        const SizedBox(height: 2),
      ],
    );
  }
}

class _SeatColumn extends StatelessWidget {
  const _SeatColumn({required this.seat, required this.compact});

  final SeatPanel seat;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 2 : 8),
            child: seat,
          ),
        ),
      ),
    );
  }
}

/// 三家出牌区：中间为玩家，两侧为两名 AI，牌面比旧版更大。
class PlayField extends StatelessWidget {
  const PlayField({super.key, required this.provider, required this.landscape});

  final GameProvider provider;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final engine = provider.engine;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / 3;
        final cardWidth = landscape ? 40.0 : 33.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final id in const [2, 0, 1])
              Expanded(
                child: _PileColumn(
                  player: engine.players[id],
                  maxWidth: columnWidth - 10,
                  cardWidth: cardWidth,
                  highlight: engine.lastPlayer == id,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PileColumn extends StatelessWidget {
  const _PileColumn({
    required this.player,
    required this.maxWidth,
    required this.cardWidth,
    required this.highlight,
  });

  final PlayerState player;
  final double maxWidth;
  final double cardWidth;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight
                        ? kGoldSoft
                        : Colors.white.withValues(alpha: 0.62),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (player.isLandlord) ...[
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '地主',
                    style: TextStyle(
                      color: Color(0xFF3A2606),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          PlayedCardsView(
            cards: player.lastPlay,
            combo: player.lastCombo,
            passed: player.lastPassed,
            maxWidth: maxWidth,
            cardWidth: cardWidth,
          ),
        ],
      ),
    );
  }
}

class TurnChip extends StatelessWidget {
  const TurnChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

/// 中央状态：轮次提示 + 最近一手动作。
class StatusInfo extends StatelessWidget {
  const StatusInfo({super.key, required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    final action = provider.engine.lastActionText;
    final landlord = provider.engine.landlord;
    final aiRevealed =
        provider.engine.revealed && landlord != null && landlord != 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TurnChip(text: provider.turnHint),
        if (aiRevealed) ...[
          const SizedBox(height: 3),
          Text(
            '地主已明牌 · 点击其座位查看手牌',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kGoldSoft.withValues(alpha: 0.8),
              fontSize: 9.5,
            ),
          ),
        ],
        if (action != null && provider.phase != GamePhase.finished) ...[
          const SizedBox(height: 2),
          Text(
            action,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}
