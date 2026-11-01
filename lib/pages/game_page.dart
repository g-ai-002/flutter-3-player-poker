import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/ddz_table_game.dart';
import '../game/game_engine.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
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
    final provider = context.read<GameProvider>();
    _table = DdzTableGame(bus: provider.events);
    if (provider.phase == GamePhase.idle) {
      provider.newGame();
    }
  }

  Future<void> _leave() async {
    final provider = context.read<GameProvider>();
    if (provider.phase == GamePhase.bidding ||
        provider.phase == GamePhase.playing) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('离开对局？'),
          content: const Text('当前对局进度不会保存。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续对局'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('离开'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    provider.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _restart() async {
    final provider = context.read<GameProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新开始？'),
        content: const Text('将放弃当前手牌，重新发牌。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重新开始'),
          ),
        ],
      ),
    );
    if (ok == true) provider.newGame();
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
                Positioned.fill(child: GameWidget(game: table)),
                SafeArea(
                  child: Column(
                    children: [
                      GameTopBar(
                        onBack: _leave,
                        onRestart: _restart,
                        compact: compact,
                      ),
                      Expanded(
                        child: GameTableArea(
                          provider: provider,
                          landscape: landscape,
                        ),
                      ),
                      if (!landscape) HumanPlayRow(provider: provider),
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
