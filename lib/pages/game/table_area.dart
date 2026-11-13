import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../../game/play_flight.dart';
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

  /// 底牌牌面宽度：正好占满顶栏高度，牌点与花色在小屏上也能看清。
  static const double cardWidth = 34;

  @override
  Widget build(BuildContext context) {
    final revealed = engine.landlord != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
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
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 9.5,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 5),
          ],
          for (final card in engine.bottomCards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: PlayingCardView(
                card: card,
                width: cardWidth,
                faceDown: !revealed,
              ),
            ),
        ],
      ),
    );
  }
}

/// 牌桌中央区域：三家出牌区聚在牌桌正中间，各自朝自家座位倾斜。
///
/// 左右两家的出牌区位于中央偏上并分别向左 / 右倾斜，玩家出牌区在中央偏下，
/// 三堆牌彼此靠近，方便一眼比较三家的上一手。中央不放常驻状态文字，
/// 轮次与提示由牌桌页的悬浮提示层承担，牌桌因此拿到完整的垂直空间。
/// 布局完成后把三处出牌区的中心、牌面尺寸与倾斜角度回传给牌桌页，
/// 供 Flame 飞牌动画精确对齐落点与大小。
class GameTableArea extends StatefulWidget {
  const GameTableArea({
    super.key,
    required this.provider,
    required this.landscape,
    this.compact = false,
    this.topInset = 0,
    this.onTargets,
    this.humanAnchor,
  });

  final GameProvider provider;
  final bool landscape;
  final bool compact;

  /// 网格上方要让给悬浮提示带的高度：提示带不参与牌桌页布局，但网格不压提示。
  final double topInset;

  /// 三家出牌区与座位的几何。
  final ValueChanged<Map<int, PlayerTarget>>? onTargets;

  /// 人类玩家的手牌定位键：玩家自己没有头像，飞牌从手牌上方起飞。
  final GlobalKey? humanAnchor;

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

  /// 两家 AI 的头像定位键；人类玩家没有头像，用 [GameTableArea.humanAnchor]。
  final Map<int, GlobalKey> _avatarKeys = {
    for (final id in const [1, 2]) id: GlobalKey(),
  };

  /// 牌桌网格的宽度与牌面宽度：出牌区几何据此估算可用叠放空间。
  double _stageWidth = 0;
  double _stageCardWidth = 0;

  /// 同一帧内的多次重建只回传一次几何，避免重复的布局查询。
  bool _reportScheduled = false;
  Map<int, PlayerTarget>? _lastTargets;

  void _scheduleReport() {
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      _reportGeometry();
    });
  }

  /// 把三家出牌区与座位的几何回传给牌桌页。
  ///
  /// 几何没变时直接跳过，选牌、快门等与几何无关的重建不再重复写回牌桌层。
  void _reportGeometry() {
    if (!mounted) return;
    final screen = MediaQuery.sizeOf(context);
    if (_stageCardWidth <= 0 || screen.isEmpty) return;
    final targets = <int, PlayerTarget>{};
    for (final entry in _pileKeys.entries) {
      final render = entry.value.currentContext?.findRenderObject();
      if (render is! RenderBox || !render.hasSize || !render.attached) return;
      // 牌堆的缩放来自出牌区的 FittedBox，取累计缩放可让飞牌尺寸与之一致。
      final scale = render.getTransformTo(null).getMaxScaleOnAxis();
      final local = Offset(
        render.size.width / 2,
        render.size.height - _stageCardWidth * PlayFlight.cardAspect / 2,
      );
      final center = render.localToGlobal(local);
      final cardWidth = _stageCardWidth * scale;
      targets[entry.key] = PlayerTarget(
        center: Offset(center.dx / screen.width, center.dy / screen.height),
        cardSize: Size(cardWidth, cardWidth * PlayFlight.cardAspect),
        maxWidth: _pileMaxWidth(entry.key),
        angle: switch (entry.key) {
          2 => -_tilt,
          1 => _tilt,
          _ => 0,
        },
        seat: _seatPoint(entry.key, screen),
      );
    }
    final previous = _lastTargets;
    if (previous != null && mapEquals(previous, targets)) return;
    _lastTargets = targets;
    widget.onTargets?.call(targets);
  }

  /// 座位起点：两家 AI 取头像中心，人类玩家取手牌上沿中点。
  ///
  /// 飞牌动画以前用经验坐标估算座位，横屏紧凑座位与大屏下会明显偏离头像。
  Offset? _seatPoint(int player, Size screen) {
    final render = (player == 0 ? widget.humanAnchor : _avatarKeys[player])
        ?.currentContext
        ?.findRenderObject();
    if (render is! RenderBox || !render.hasSize || render.size.isEmpty) {
      return null;
    }
    final point = render.localToGlobal(
      player == 0
          ? Offset(render.size.width / 2, 0)
          : render.size.center(Offset.zero),
    );
    return Offset(point.dx / screen.width, point.dy / screen.height);
  }

  /// 出牌区叠放可用的横向宽度：与 [_stage] 里的牌堆槽位一致。
  double _pileMaxWidth(int player) => _stageWidth * (player == 0 ? 0.42 : 0.26);

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
      avatarKey: _avatarKeys[player.id],
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
            hidden: provider.isPlayFlying(player.id),
            maxWidth: maxWidth,
            cardWidth: cardWidth,
          ),
        ),
      ],
    );
  }

  /// 左右两家出牌区朝各自座位倾斜的角度。
  static const double _tilt = 0.14;

  @override
  Widget build(BuildContext context) {
    _scheduleReport();
    final provider = widget.provider;
    final left = provider.engine.players[2];
    final right = provider.engine.players[1];
    final leftSeat = _seatPanel(context, provider, left);
    final rightSeat = _seatPanel(context, provider, right);
    return Padding(
      padding: EdgeInsets.only(top: widget.topInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          if (widget.landscape) {
            return Stack(
              children: [
                Positioned.fill(child: _stage(provider, width, height)),
                _seatOverlay(leftSeat, width, left: 8),
                _seatOverlay(rightSeat, width, right: 8),
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
                      child: _scaledSeat(leftSeat),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 2),
                      child: _scaledSeat(rightSeat),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, stage) =>
                      _stage(provider, stage.maxWidth, stage.maxHeight),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 三堆牌围绕牌桌中心呈三角排列：左家偏上左倾，右家偏上右倾，玩家贴底居中。
  Widget _stage(GameProvider provider, double width, double height) {
    // 牌面随牌桌宽度线性放大到 96 像素封顶，1440p / 4K 桌面不再显示偏小的牌。
    final cardWidth = (width / 16).clamp(34.0, 96.0);
    _stageWidth = width;
    _stageCardWidth = cardWidth;
    final engine = provider.engine;
    final sideWidth = width * 0.26;
    final leftPile = _pile(provider, engine.players[2], cardWidth, sideWidth);
    final rightPile = _pile(provider, engine.players[1], cardWidth, sideWidth);
    final humanPile = _pile(
      provider,
      engine.players[0],
      cardWidth,
      width * 0.42,
    );
    // 提示带已在网格上方预留（见 GameLayout.hintBand），牌堆只需留一点呼吸位。
    const sideTop = 6.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _placePile(
          leftPile,
          keyId: 2,
          left: width * 0.16,
          top: sideTop,
          width: width * 0.28,
          height: height * 0.44,
          angle: -_tilt,
        ),
        _placePile(
          humanPile,
          keyId: 0,
          left: width * 0.28,
          bottom: 0,
          width: width * 0.44,
          height: height * 0.42,
        ),
        _placePile(
          rightPile,
          keyId: 1,
          right: width * 0.16,
          top: sideTop,
          width: width * 0.28,
          height: height * 0.44,
          angle: _tilt,
        ),
      ],
    );
  }

  /// 出牌区槽位：整体缩放后按座位方向旋转，牌堆中心就是飞牌动画的落点。
  Widget _placePile(
    Widget child, {
    required int keyId,
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double width,
    required double height,
    double angle = 0,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Transform.rotate(
          key: ValueKey('pile-tilt-$keyId'),
          angle: angle,
          child: child,
        ),
      ),
    );
  }

  /// 横屏时座位悬浮在牌桌左上 / 右上，不与中央牌堆争夺布局空间。
  ///
  /// 右侧座位按右上对齐，两侧到屏幕边缘的留白才与左家一致。
  Widget _seatOverlay(
    Widget seat,
    double width, {
    double? left,
    double? right,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: 2,
      width: width * 0.22,
      height: widget.compact ? 40 : 96,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: right != null ? Alignment.topRight : Alignment.topLeft,
        child: seat,
      ),
    );
  }

  Widget _scaledSeat(Widget seat) {
    return FittedBox(fit: BoxFit.scaleDown, child: seat);
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
