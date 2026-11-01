import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/played_cards_view.dart';
import '../../widgets/playing_card_view.dart';
import '../../widgets/seat_panel.dart';

/// 牌桌中央区域：横屏时两侧座位并排，竖屏时座位在上、出牌区居中。
class GameTableArea extends StatelessWidget {
  const GameTableArea({
    super.key,
    required this.provider,
    required this.landscape,
  });

  final GameProvider provider;
  final bool landscape;

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
            flex: 3,
            child: _SideColumn(
              player: left,
              isLeft: true,
              seat: _seatPanel(context, provider, left),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BottomCards(engine: engine),
                const SizedBox(height: 10),
                StatusInfo(provider: provider),
                const SizedBox(height: 8),
                PlayedCardsView(
                  cards: engine.players[0].lastPlay,
                  combo: engine.players[0].lastCombo,
                  passed: engine.players[0].lastPassed,
                  maxWidth: 230,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: _SideColumn(
              player: right,
              isLeft: false,
              seat: _seatPanel(context, provider, right),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 2),
                child: _seatPanel(context, provider, left),
              ),
              Expanded(child: BottomCards(engine: engine)),
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: _seatPanel(context, provider, right),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: PlayedCardsView(
                      cards: left.lastPlay,
                      combo: left.lastCombo,
                      passed: left.lastPassed,
                      maxWidth: 170,
                    ),
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: Center(child: StatusInfo(provider: provider)),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: PlayedCardsView(
                      cards: right.lastPlay,
                      combo: right.lastCombo,
                      passed: right.lastPassed,
                      maxWidth: 170,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.player,
    required this.isLeft,
    required this.seat,
  });

  final PlayerState player;
  final bool isLeft;
  final SeatPanel seat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isLeft ? 10 : 4, right: isLeft ? 4 : 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          seat,
          const SizedBox(height: 10),
          PlayedCardsView(
            cards: player.lastPlay,
            combo: player.lastCombo,
            passed: player.lastPassed,
            maxWidth: 160,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

/// 横屏中央状态：轮次提示 + 最近一手动作。
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
          const SizedBox(height: 4),
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
          const SizedBox(height: 4),
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

/// 三张底牌：地主确定前背面朝上。
class BottomCards extends StatelessWidget {
  const BottomCards({super.key, required this.engine});

  final DdzEngine engine;

  @override
  Widget build(BuildContext context) {
    final revealed = engine.landlord != null;
    return Column(
      children: [
        const SizedBox(height: 2),
        Text(
          '底牌',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final card in engine.bottomCards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: PlayingCardView(
                  card: card,
                  width: 30,
                  faceDown: !revealed,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 竖屏时人类玩家在牌桌上方的出牌区。
class HumanPlayRow extends StatelessWidget {
  const HumanPlayRow({super.key, required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    final human = provider.engine.players[0];
    return SizedBox(
      height: 58,
      child: Center(
        child: PlayedCardsView(
          cards: human.lastPlay,
          combo: human.lastCombo,
          passed: human.lastPassed,
          maxWidth: 220,
        ),
      ),
    );
  }
}
