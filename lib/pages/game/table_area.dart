import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../../providers/game_provider.dart';
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
            child: _SideColumn(provider: provider, player: left, isLeft: true),
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
              provider: provider,
              player: right,
              isLeft: false,
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
                child: SeatPanel(
                  player: left,
                  isCurrent: engine.currentPlayer == 2,
                  thinking: provider.thinkingPlayer == 2,
                  phase: engine.phase,
                ),
              ),
              Expanded(child: BottomCards(engine: engine)),
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: SeatPanel(
                  player: right,
                  isCurrent: engine.currentPlayer == 1,
                  thinking: provider.thinkingPlayer == 1,
                  phase: engine.phase,
                ),
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
    required this.provider,
    required this.player,
    required this.isLeft,
  });

  final GameProvider provider;
  final PlayerState player;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isLeft ? 10 : 4, right: isLeft ? 4 : 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SeatPanel(
            player: player,
            isCurrent: provider.engine.currentPlayer == player.id,
            thinking: provider.thinkingPlayer == player.id,
            phase: provider.engine.phase,
          ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TurnChip(text: provider.turnHint),
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
