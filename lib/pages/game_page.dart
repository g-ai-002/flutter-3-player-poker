import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/card_counter.dart';
import '../game/ddz_table_game.dart';
import '../game/game_engine.dart';
import '../game/play_flight.dart';
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
/// 牌桌网格始终居中，顶部让出悬浮顶栏与提示带，底部让出操作 dock 与手牌；
/// 轮次、上一手、残局与临时反馈都悬浮在网格四周，不参与布局，也不会推挤牌桌。
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GlobalKey _gameKey = GlobalKey();
  late final GameProvider _provider;
  DdzTableGame? _table;
  bool _counterOpen = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<GameProvider>();
    enterGameFullscreen();
    _table = DdzTableGame(
      bus: _provider.events,
      introDeal: true,
      logicHz: _provider.settings.logicRate.hz,
    );
    if (_provider.phase == GamePhase.idle) _provider.newGame();
  }

  @override
  void dispose() {
    // 静默收尾：取消 AI / 提示定时器与背景音乐，再停掉 Flame 循环并退订事件。
    _provider.shutdown();
    _table?.detach();
    exitGameFullscreen();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_provider.phase == GamePhase.bidding ||
        _provider.phase == GamePhase.doubling ||
        _provider.phase == GamePhase.playing) {
      final leave = await showConfirmDialog(
        context,
        title: '离开对局？',
        message: '当前对局进度不会保存。',
        confirmLabel: '离开',
        cancelLabel: '继续对局',
      );
      if (!leave) return;
    }
    _provider.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _restart() async {
    final ok = await showConfirmDialog(
      context,
      title: '重新开始？',
      message: '将放弃当前手牌，重新发牌。',
      confirmLabel: '重新开始',
    );
    if (ok) _provider.newGame();
  }

  /// 把出牌区的中心、牌面尺寸与倾斜角度交给牌桌层，飞牌动画据此精确落位。
  void _syncPileTargets(Map<int, PileTarget> targets) {
    _table?.setPileTargets(targets);
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
            final sides = GameLayout.sideHints(constraints.maxWidth);
            // 横屏全屏时刘海与挖孔都在左右两侧，悬浮层统一避开安全区。
            final padding = MediaQuery.paddingOf(context);
            final safeTop = padding.top;
            final safeLeft = 8 + padding.left;
            final safeRight = 8 + padding.right;
            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: GameWidget(key: _gameKey, game: table),
                  ),
                ),
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
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: GameTableArea(
                                  provider: provider,
                                  landscape: landscape,
                                  compact: compact,
                                  topInset: GameLayout.hintBand(sides: sides),
                                  onPileTargets: _syncPileTargets,
                                ),
                              ),
                              if (!_counterOpen)
                                Positioned.fill(
                                  child: GameHints(
                                    provider: provider,
                                    showSelection: narrow,
                                    sides: sides,
                                  ),
                                ),
                            ],
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
                // 记牌器与提示层互斥显示，避免文字叠加。
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
