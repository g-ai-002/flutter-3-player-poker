import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/played_cards_view.dart';
import '../../widgets/playing_card_view.dart';
import '../../widgets/seat_panel.dart';

/// 顶栏中央的底牌胶囊：开局背面朝上，地主确定后亮出。
///
/// 底牌内嵌在悬浮顶栏里，不再单独占用一条横向空间。
class BottomCardsBar extends StatelessWidget {
  const BottomCardsBar({super.key, required this.engine, this.compact = false});

  final DdzEngine engine;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final revealed = engine.landlord != null;
    final width = compact ? 22.0 : 24.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Text(
              '底牌',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 6),
          ],
          for (final card in engine.bottomCards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
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
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}

/// 牌桌中央区域：三家出牌区呈三足鼎立。
///
/// 左右两家在牌桌两侧偏上，玩家出牌区贴底居中；中央不再放常驻状态文字，
/// 轮次与提示由牌桌页的悬浮提示层承担，牌桌因此拿到完整的垂直空间。
/// 布局完成后把三处出牌区的屏幕坐标回传给牌桌页，供 Flame 飞牌动画落点使用。
class GameTableArea extends StatefulWidget {
  const GameTableArea({
    super.key,
    required this.provider,
    required this.landscape,
    this.compact = false,
    this.onPileCenters,
  });

  final GameProvider provider;
  final bool landscape;
  final bool compact;

  /// 三家出牌区的全局坐标（0 玩家、1 右侧、2 左侧）。
  final ValueChanged<Map<int, Offset>>? onPileCenters;

  /// 竖屏座位条高度：悬浮提示层据此避开左右座位。
  static double portraitSeatHeight({bool compact = false}) =>
      compact ? 60 : 106;

  @override
  State<GameTableArea> createState() => _GameTableAreaState();
}

class _GameTableAreaState extends State<GameTableArea> {
  final Map<int, GlobalKey> _pileKeys = {
    for (final id in const [0, 1, 2]) id: GlobalKey(),
  };

  void _reportPileCenters() {
    if (!mounted) return;
    final callback = widget.onPileCenters;
    if (callback == null) return;
    final centers = <int, Offset>{};
    for (final entry in _pileKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      centers[entry.key] = box.localToGlobal(box.size.center(Offset.zero));
    }
    callback(centers);
  }

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

  Widget _seatPanel(
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
      compact: widget.compact,
      onTap: revealed ? () => _showRevealedHand(context, player) : null,
    );
  }

  Widget _pile(
    GameProvider provider,
    PlayerState player,
    double cardWidth,
    double maxWidth,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PileLabel(
          player: player,
          highlight: provider.engine.lastPlayer == player.id,
        ),
        const SizedBox(height: 3),
        KeyedSubtree(
          key: _pileKeys[player.id],
          child: PlayedCardsView(
            cards: player.lastPlay,
            combo: player.lastCombo,
            passed: player.lastPassed,
            maxWidth: maxWidth,
            cardWidth: cardWidth,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportPileCenters());
    final provider = widget.provider;
    final engine = provider.engine;
    final left = engine.players[2];
    final right = engine.players[1];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 牌面随牌桌宽度线性放大到 96 像素封顶，1440p / 4K 桌面不再显示偏小的牌。
        final cardWidth = (width / 16).clamp(34.0, 96.0);
        final sideWidth = width * 0.3 - 18;
        final centerWidth = width * 0.4 - 18;

        final leftPile = _pile(provider, left, cardWidth, sideWidth);
        final rightPile = _pile(provider, right, cardWidth, sideWidth);
        final humanPile = _pile(
          provider,
          engine.players[0],
          cardWidth,
          centerWidth,
        );

        if (widget.landscape) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: _SideColumn(
                  seat: _seatPanel(context, provider, left),
                  pile: leftPile,
                  compact: widget.compact,
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(fit: BoxFit.scaleDown, child: humanPile),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: _SideColumn(
                  seat: _seatPanel(context, provider, right),
                  pile: rightPile,
                  compact: widget.compact,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(
              height: GameTableArea.portraitSeatHeight(
                compact: widget.compact,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 2),
                    child: _scaledSeat(_seatPanel(context, provider, left)),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: _scaledSeat(_seatPanel(context, provider, right)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FittedBox(fit: BoxFit.scaleDown, child: leftPile),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FittedBox(fit: BoxFit.scaleDown, child: humanPile),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: FittedBox(fit: BoxFit.scaleDown, child: rightPile),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _scaledSeat(Widget seat) {
    return FittedBox(fit: BoxFit.scaleDown, child: seat);
  }
}

/// 侧边座位：座位信息在上，出牌区紧随其下，形成牌桌左上 / 右上的一角。
class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.seat,
    required this.pile,
    required this.compact,
  });

  final Widget seat;
  final Widget pile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          const SizedBox(height: 2),
          // 座位只占牌桌上方一小条，剩下的空间留给放大的出牌区。
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: compact ? 42 : 110),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 0 : 4),
                child: seat,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(fit: BoxFit.scaleDown, child: pile),
            ),
          ),
        ],
      ),
    );
  }
}

/// 出牌区上方的小标签：谁出的牌、是否是上一手。
class PileLabel extends StatelessWidget {
  const PileLabel({super.key, required this.player, this.highlight = false});

  final PlayerState player;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
    );
  }
}
