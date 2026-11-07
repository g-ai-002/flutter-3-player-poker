import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/card_counter.dart';
import '../game/ddz_table_game.dart';
import '../game/game_engine.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../utils/screen_mode.dart';
import '../widgets/card_counter_overlay.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/turn_countdown.dart';
import 'game/game_action_bar.dart';
import 'game/game_hints.dart';
import 'game/game_layout.dart';
import 'game/game_overlays.dart';
import 'game/game_top_bar.dart';
import 'game/table_area.dart';

/// 牌桌页：组合 Flame 视觉层与 Flutter 交互层，并负责页面级对话框。
///
/// 牌桌拿到的空间是整屏只扣掉「悬浮顶栏固定高度 + 底部操作 dock + 手牌」后的全部剩余，
/// 轮次、上一手与临时反馈都悬浮在牌桌上方，不参与布局，也不会推挤牌桌。
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GlobalKey _gameKey = GlobalKey();
  DdzTableGame? _table;
  bool _counterOpen = false;

  @override
  void initState() {
    super.initState();
    enterGameFullscreen();
    final provider = context.read<GameProvider>();
    _table = DdzTableGame(
      bus: provider.events,
      introDeal: true,
      logicHz: provider.settings.logicRate.hz,
    );
    if (provider.phase == GamePhase.idle) {
      provider.newGame();
    }
  }

  @override
  void dispose() {
    exitGameFullscreen();
    super.dispose();
  }

  Future<void> _leave() async {
    final provider = context.read<GameProvider>();
    if (provider.phase == GamePhase.bidding ||
        provider.phase == GamePhase.doubling ||
        provider.phase == GamePhase.playing) {
      final leave = await showConfirmDialog(
        context,
        title: '离开对局？',
        message: '当前对局进度不会保存。',
        confirmLabel: '离开',
        cancelLabel: '继续对局',
      );
      if (!leave) return;
    }
    provider.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _restart() async {
    final provider = context.read<GameProvider>();
    final ok = await showConfirmDialog(
      context,
      title: '重新开始？',
      message: '将放弃当前手牌，重新发牌。',
      confirmLabel: '重新开始',
    );
    if (ok) provider.newGame();
  }

  /// 把出牌区的屏幕坐标换算成牌桌内的相对坐标，飞牌动画据此落地。
  void _syncPileCenters(Map<int, Offset> centers) {
    final box = _gameKey.currentContext?.findRenderObject() as RenderBox?;
    final table = _table;
    if (box == null || !box.hasSize || table == null) return;
    final size = box.size;
    if (size.isEmpty) return;
    table.setPileAnchors({
      for (final entry in centers.entries)
        if (box.globalToLocal(entry.value) case final local)
          entry.key: Offset(
            (local.dx / size.width).clamp(0.0, 1.0),
            (local.dy / size.height).clamp(0.0, 1.0),
          ),
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final table = _table!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: kFeltDark,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 560;
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final narrow = constraints.maxWidth < GameLayout.narrowWidth;
            // 横屏全屏时刘海与挖孔都在左右两侧，悬浮层统一避开安全区。
            final padding = MediaQuery.paddingOf(context);
            final safeTop = padding.top;
            final safeLeft = 8 + padding.left;
            final safeRight = 8 + padding.right;
            // 竖屏时座位条横在牌桌上沿，提示层顺势下移，始终避开两侧座位。
            final seatInset = landscape
                ? 0.0
                : GameTableArea.portraitSeatHeight(compact: compact) + 2;
            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: GameWidget(key: _gameKey, game: table),
                  ),
                ),
                // 牌桌与底部交互区：只让出悬浮顶栏的固定高度，其余空间全部给牌桌。
                SafeArea(
                  child: Column(
                    children: [
                      TurnClock(
                        provider: provider,
                        serial: provider.engine.turnSerial,
                        active: provider.phase == GamePhase.playing,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: GameTopBar.height,
                          ),
                          child: GameTableArea(
                            provider: provider,
                            landscape: landscape,
                            compact: compact,
                            onPileCenters: _syncPileCenters,
                          ),
                        ),
                      ),
                      GameActionBar(provider: provider),
                      HumanHandView(provider: provider, compact: compact),
                    ],
                  ),
                ),
                Positioned(
                  top: safeTop,
                  left: safeLeft,
                  right: safeRight,
                  child: GameTopBar(
                    onBack: _leave,
                    onRestart: _restart,
                    counterOpen: _counterOpen,
                    onToggleCounter: () =>
                        setState(() => _counterOpen = !_counterOpen),
                  ),
                ),
                // 提示层与记牌器都贴在悬浮顶栏下方，互斥显示避免文字叠加。
                if (!_counterOpen)
                  Positioned(
                    top: safeTop + GameTopBar.height + 2 + seatInset,
                    left: safeLeft + 4,
                    right: safeRight + 4,
                    child: GameHints(provider: provider, showSelection: narrow),
                  ),
                if (_counterOpen)
                  Positioned(
                    top: safeTop + GameTopBar.height + 2,
                    left: safeLeft + 4,
                    right: safeRight + 4,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: CardCounterOverlay(
                          counts: CardCounter.remaining(provider.engine),
                          onClose: () => setState(() => _counterOpen = false),
                        ),
                      ),
                    ),
                  ),
                if (provider.phase == GamePhase.bidding &&
                    provider.engine.currentPlayer == 0)
                  BidOverlay(provider: provider, onLeave: _leave),
                if (provider.phase == GamePhase.doubling &&
                    provider.engine.currentPlayer == 0)
                  DoubleOverlay(provider: provider, onLeave: _leave),
                if (provider.phase == GamePhase.finished)
                  ResultOverlay(
                    provider: provider,
                    onLeave: _leave,
                    onRestart: provider.newGame,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
