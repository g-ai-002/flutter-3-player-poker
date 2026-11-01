import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/ddz_table_game.dart';
import '../game/game_engine.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/hand_view.dart';
import '../widgets/played_cards_view.dart';
import '../widgets/playing_card_view.dart';
import '../widgets/seat_panel.dart';
import 'rules_page.dart';

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
                      _TopBar(
                        onBack: _leave,
                        onRestart: _restart,
                        compact: compact,
                      ),
                      Expanded(
                        child: _TableArea(
                          provider: provider,
                          landscape: landscape,
                        ),
                      ),
                      if (!landscape) _HumanPlayRow(provider: provider),
                      if (provider.phase == GamePhase.playing)
                        _ActionBar(provider: provider),
                      _HumanHand(provider: provider, compact: compact),
                    ],
                  ),
                ),
                if (provider.feedback != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: provider.phase == GamePhase.playing ? 200 : 120,
                    child: Center(
                      child: _FeedbackToast(text: provider.feedback!),
                    ),
                  ),
                if (provider.phase == GamePhase.bidding &&
                    provider.engine.currentPlayer == 0)
                  _BidOverlay(provider: provider, onLeave: _leave),
                if (provider.phase == GamePhase.finished)
                  _ResultOverlay(
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onRestart,
    this.compact = false,
  });

  final VoidCallback onBack;
  final VoidCallback onRestart;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final landlord = provider.engine.landlord;
    final landlordName = landlord == null
        ? '未定'
        : provider.engine.players[landlord].name;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: Colors.white.withValues(alpha: 0.85),
            tooltip: '返回',
            constraints: compact
                ? const BoxConstraints.tightFor(width: 40, height: 40)
                : null,
            padding: compact ? EdgeInsets.zero : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '斗地主',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '地主：$landlordName',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGold.withValues(alpha: 0.35)),
            ),
            child: Text(
              '倍数 ×${provider.engine.multiplier}',
              style: const TextStyle(
                color: kGoldSoft,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF163526),
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
            onSelected: (value) {
              if (value == 'restart') onRestart();
              if (value == 'rules') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RulesPage()),
                );
              }
              if (value == 'leave') onBack();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'restart', child: Text('重新开始')),
              PopupMenuItem(value: 'rules', child: Text('玩法说明')),
              PopupMenuItem(value: 'leave', child: Text('返回主页')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableArea extends StatelessWidget {
  const _TableArea({required this.provider, required this.landscape});

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
                _BottomCards(engine: engine),
                const SizedBox(height: 10),
                _StatusInfo(provider: provider),
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
                ),
              ),
              Expanded(child: _BottomCards(engine: engine)),
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: SeatPanel(
                  player: right,
                  isCurrent: engine.currentPlayer == 1,
                  thinking: provider.thinkingPlayer == 1,
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
                child: Center(child: _TurnChip(text: provider.turnHint)),
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

class _TurnChip extends StatelessWidget {
  const _TurnChip({required this.text});

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

class _StatusInfo extends StatelessWidget {
  const _StatusInfo({required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    final action = provider.engine.lastActionText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TurnChip(text: provider.turnHint),
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

class _BottomCards extends StatelessWidget {
  const _BottomCards({required this.engine});

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
            for (var i = 0; i < engine.bottomCards.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: PlayingCardView(
                  card: engine.bottomCards[i],
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

class _HumanPlayRow extends StatelessWidget {
  const _HumanPlayRow({required this.provider});

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

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.provider});

  final GameProvider provider;

  @override
  Widget build(BuildContext context) {
    final selected = provider.selectedCombo;
    final label = provider.selectedCards.isEmpty
        ? '请选择要出的牌'
        : selected?.description ?? '牌型不合法';
    final canHint = provider.isHumanTurn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: provider.selectedCards.isEmpty
                        ? Colors.white.withValues(alpha: 0.55)
                        : kGoldSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.humanIsLandlord
                      ? '地主 · 剩余 ${provider.humanHand.length} 张'
                      : '农民 · 剩余 ${provider.humanHand.length} 张',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _ActionButton(
            label: '提示',
            onPressed: canHint ? provider.hint : null,
            outlined: true,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            label: '不出',
            onPressed: provider.canPass ? provider.pass : null,
            outlined: true,
          ),
          const SizedBox(width: 4),
          _ActionButton(
            label: '出牌',
            onPressed: provider.canPlay ? provider.playSelected : null,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    if (outlined) {
      return SizedBox(
        height: 38,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.25),
            side: BorderSide(
              color: onPressed == null
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.35),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: shape,
          ),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );
    }
    return SizedBox(
      height: 38,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kGold,
          foregroundColor: const Color(0xFF2C1D04),
          disabledBackgroundColor: kGold.withValues(alpha: 0.22),
          disabledForegroundColor: const Color(0xFF2C1D04)
              .withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          shape: shape,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _HumanHand extends StatelessWidget {
  const _HumanHand({required this.provider, this.compact = false});

  final GameProvider provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 2, 12, compact ? 4 : 8),
      child: HandView(
        cards: provider.humanHand,
        selectedIds: provider.selectedIds,
        enabled: provider.isHumanTurn,
        onTap: provider.toggleCard,
        maxCardWidth: compact ? 44 : null,
      ),
    );
  }
}

class _FeedbackToast extends StatelessWidget {
  const _FeedbackToast({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xF0182B20),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kGold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _BidOverlay extends StatelessWidget {
  const _BidOverlay({required this.provider, required this.onLeave});

  final GameProvider provider;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: onLeave,
                icon: const Icon(Icons.close, size: 20),
                color: Colors.white54,
                tooltip: '离开',
              ),
            ),
            Center(
              child: Container(
                width: math.min(330, MediaQuery.sizeOf(context).width - 40),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF14301F),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kGold.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '轮到你叫地主',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '王、2 和炸弹越多，叫地主越有优势。\n成为地主可拿走 3 张底牌，并以一敌二。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => provider.bid(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text('不叫'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => provider.bid(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: const Color(0xFF2C1D04),
                            ),
                            child: const Text(
                              '叫地主',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.provider,
    required this.onLeave,
    required this.onRestart,
  });

  final GameProvider provider;
  final VoidCallback onLeave;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final result = provider.result;
    if (result == null) return const SizedBox.shrink();
    final won = result.humanWon(provider.humanIsLandlord);
    final score = result.scores[0];
    final tags = <String>[
      provider.humanIsLandlord ? '地主' : '农民',
      if (result.spring) '春天',
      if (result.antiSpring) '反春天',
    ];
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.58),
        child: Center(
          child: Container(
            width: math.min(340, MediaQuery.sizeOf(context).width - 40),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B3C29), Color(0xFF0E2419)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGold.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.emoji_events_rounded : Icons.handshake_outlined,
                  size: 44,
                  color: won ? kGold : Colors.white54,
                ),
                const SizedBox(height: 8),
                Text(
                  won ? '胜利' : '惜败',
                  style: TextStyle(
                    color: won ? kGoldSoft : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${tags.join(' · ')} · 倍数 ×${result.multiplier}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '本局得分',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${score >= 0 ? '+' : ''}$score',
                        style: TextStyle(
                          color: score >= 0
                              ? kGoldSoft
                              : const Color(0xFFE08A7A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onLeave,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Text('返回主页'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onRestart,
                        style: FilledButton.styleFrom(
                          backgroundColor: kGold,
                          foregroundColor: const Color(0xFF2C1D04),
                        ),
                        child: const Text(
                          '再来一局',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
