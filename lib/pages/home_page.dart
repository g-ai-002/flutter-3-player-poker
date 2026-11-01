import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../models/playing_card.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/playing_card_view.dart';
import 'game_page.dart';
import 'hand_history_page.dart';
import 'rules_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _startGame(BuildContext context) {
    context.read<GameProvider>().newGame();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const GamePage()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final dark = settings.darkMode;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF07160F), Color(0xFF0D2E1D)]
                : const [Color(0xFFF9F5EA), Color(0xFFE9EADB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '本地单机',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: dark ? '切换浅色' : '切换深色',
                          onPressed: () => settings.setDarkMode(!dark),
                          icon: Icon(
                            dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _HeroPanel(level: settings.aiLevel),
                    const SizedBox(height: 18),
                    _StartButton(onPressed: () => _startGame(context)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _NavTile(
                            icon: Icons.menu_book_outlined,
                            label: '玩法说明',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RulesPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _NavTile(
                            icon: Icons.insights_outlined,
                            label: '数据统计',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const StatsPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _NavTile(
                            icon: Icons.receipt_long_outlined,
                            label: '牌谱',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const HandHistoryPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _NavTile(
                            icon: Icons.tune,
                            label: '设置',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SettingsPage(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Center(
                      child: Text(
                        '无需联网 · 随时随地来一局 · v${AppConstants.version}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 10.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.level});

  final AiLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C6A47), Color(0xFF0C2E1D)],
        ),
        border: Border.all(color: kGold.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 92,
            width: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _fanCard(angle: -0.22, offset: -44, card: _demoCard(12, 1)),
                _fanCard(angle: -0.11, offset: -22, card: _demoCard(13, 0)),
                _fanCard(
                  angle: 0,
                  offset: 0,
                  card: _demoCard(17, 4),
                  highlighted: true,
                ),
                _fanCard(angle: 0.11, offset: 22, card: _demoCard(16, 4)),
                _fanCard(angle: 0.22, offset: 44, card: _demoCard(14, 2)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '斗地主',
            style: TextStyle(
              color: kGoldSoft,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '经典三人玩法 · ${level.label} AI 对手',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ListenableBuilder(
              listenable: StatsService.instance,
              builder: (context, _) {
                final stats = StatsService.instance.stats;
                return Row(
                  children: [
                    _Metric(label: '对局', value: '${stats.games}'),
                    _divider(),
                    _Metric(label: '胜率', value: stats.winRateLabel),
                    _divider(),
                    _Metric(
                      label: '积分',
                      value: '${stats.totalScore}',
                      highlight: stats.totalScore > 0,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static PlayingCard _demoCard(int rank, int suitIndex) {
    const suits = [
      CardSuit.spade,
      CardSuit.heart,
      CardSuit.club,
      CardSuit.diamond,
      CardSuit.joker,
    ];
    return PlayingCard(
      id: 900 + rank,
      rank: rank,
      suit: suits[suitIndex % suits.length],
    );
  }

  Widget _fanCard({
    required double angle,
    required double offset,
    required PlayingCard card,
    bool highlighted = false,
  }) {
    return Transform.translate(
      offset: Offset(offset, highlighted ? -6 : 0),
      child: Transform.rotate(
        angle: angle,
        child: PlayingCardView(
          card: card,
          width: highlighted ? 56 : 50,
          selected: highlighted,
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 0.6,
    height: 26,
    color: Colors.white.withValues(alpha: 0.1),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? kGoldSoft : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded, size: 24),
        label: const Text(
          '开始对局',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        style: goldButtonStyle(
          padding: EdgeInsets.zero,
          fontSize: 16,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          children: [
            Icon(icon, size: 21, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
