import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/ddz_table_game.dart';
import '../game/game_engine.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../utils/screen_mode.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/turn_countdown.dart';
import 'game/game_action_bar.dart';
import 'game/game_overlays.dart';
import 'game/game_top_bar.dart';
import 'game/table_area.dart';

/// 牌桌页：组合 Flame 视觉层与 Flutter 交互层，并负责页面级对话框。
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  DdzTableGame? _table;

  @override
  void initState() {
    super.initState();
    enterGameFullscreen();
    final provider = context.read<GameProvider>();
    _table = DdzTableGame(bus: provider.events, introDeal: true);
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
            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(child: GameWidget(game: table)),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      TurnClock(
                        provider: provider,
                        serial: provider.engine.turnSerial,
                        active: provider.phase == GamePhase.playing,
                      ),
                      GameTopBar(
                        onBack: _leave,
                        onRestart: _restart,
                        compact: compact,
                      ),
                      BottomCardsBar(engine: provider.engine, compact: compact),
                      Expanded(
                        child: GameTableArea(
                          provider: provider,
                          landscape: landscape,
                          compact: compact,
                        ),
                      ),
                      if (provider.phase == GamePhase.playing)
                        GameActionBar(provider: provider),
                      HumanHandView(provider: provider, compact: compact),
                    ],
                  ),
                ),
                if (provider.feedback != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: provider.phase == GamePhase.playing ? 200 : 120,
                    child: Center(
                      child: FeedbackToast(text: provider.feedback!),
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
