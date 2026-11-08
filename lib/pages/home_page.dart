import 'dart:math' as math;

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

/// 主页：窄屏单列，宽屏双栏，矮窗口并排。
///
/// 手机竖屏保持一列纵向排布；桌面、平板横屏与手机横屏把主视觉与入口左右分开，
/// 大屏不再把内容挤在 520 逻辑像素的中间条里，矮屏也不用滚动才能点到「开始对局」。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// 宽屏断点：达到后启用双栏，主视觉随之放大。
  static const double wideWidth = 900;

  /// 矮窗口断点：手机横屏与小窗优先保证入口可见。
  static const double shortHeight = 620;

  /// 矮窗口改为并排所需的最小宽度，再窄仍回退到单列滚动。
  static const double sideBySideWidth = 560;

  static final List<(IconData, String, WidgetBuilder)> _navItems = [
    (Icons.menu_book_outlined, '玩法说明', (_) => const RulesPage()),
    (Icons.insights_outlined, '数据统计', (_) => const StatsPage()),
    (Icons.receipt_long_outlined, '牌谱', (_) => const HandHistoryPage()),
    (Icons.tune, '设置', (_) => const SettingsPage()),
  ];

  void _open(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  void _startGame(BuildContext context) {
    context.read<GameProvider>().newGame();
    _open(context, (_) => const GamePage());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final dark = settings.darkMode;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= wideWidth;
              final short = constraints.maxHeight < shortHeight;
              final sideBySide =
                  wide || (short && constraints.maxWidth >= sideBySideWidth);
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1120 : 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: ConstrainedBox(
                      // 内容不足一屏时垂直居中，大窗口下不会顶在屏幕最上面。
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 28),
                      ),
                      child: Center(
                        child: sideBySide
                            ? _wideBody(context, settings, dense: short)
                            : _columnBody(context, settings),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _columnBody(BuildContext context, SettingsProvider settings) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, settings),
        const SizedBox(height: 4),
        _HeroPanel(level: settings.aiLevel),
        const SizedBox(height: 18),
        _StartButton(onPressed: () => _startGame(context)),
        const SizedBox(height: 18),
        _navTiles(context),
        const SizedBox(height: 26),
        _footer(scheme),
      ],
    );
  }

  Widget _wideBody(
    BuildContext context,
    SettingsProvider settings, {
    required bool dense,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _HeroPanel(
            level: settings.aiLevel,
            large: !dense,
            dense: dense,
          ),
        ),
        SizedBox(width: dense ? 20 : 32),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, settings),
              SizedBox(height: dense ? 10 : 14),
              _StartButton(onPressed: () => _startGame(context), dense: dense),
              SizedBox(height: dense ? 10 : 14),
              _navTiles(context, perRow: 2, dense: dense),
              SizedBox(height: dense ? 14 : 22),
              _footer(scheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, SettingsProvider settings) {
    final dark = settings.darkMode;
    return Row(
      children: [
        Text(
          '本地单机',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: dark ? '切换浅色' : '切换深色',
          onPressed: () => settings.setDarkMode(!dark),
          icon: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
          ),
        ),
      ],
    );
  }

  /// 入口按钮：单列页排成一行，宽屏右栏拆成 2×2 两行，窄栏更易点。
  Widget _navTiles(BuildContext context, {int perRow = 4, bool dense = false}) {
    return Column(
      children: [
        for (var start = 0; start < _navItems.length; start += perRow) ...[
          if (start > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (
                var i = start;
                i < math.min(start + perRow, _navItems.length);
                i++
              ) ...[
                if (i > start) const SizedBox(width: 8),
                Expanded(
                  child: _NavTile(
                    icon: _navItems[i].$1,
                    label: _navItems[i].$2,
                    dense: dense,
                    onTap: () => _open(context, _navItems[i].$3),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _footer(ColorScheme scheme) {
    return Text(
      '无需联网 · 随时随地来一局 · v${AppConstants.version}',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        fontSize: 10.5,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.level,
    this.large = false,
    this.dense = false,
  });

  final AiLevel level;

  /// 桌面宽屏主视觉：牌扇与标题放大，填满更大的舞台。
  final bool large;

  /// 矮窗口主视觉：压缩高度，把屏幕留给入口。
  final bool dense;

  static const _fan = <(double, double, int, int, bool)>[
    (-0.22, -44, 12, 1, false),
    (-0.11, -22, 13, 0, false),
    (0, 0, 17, 4, true),
    (0.11, 22, 16, 4, false),
    (0.22, 44, 14, 2, false),
  ];

  @override
  Widget build(BuildContext context) {
    final fanHeight = dense ? 62.0 : (large ? 142.0 : 92.0);
    final fanWidth = dense ? 138.0 : (large ? 252.0 : 180.0);
    final fanScale = dense ? 0.68 : (large ? 1.4 : 1.0);
    final cardWidth = 50 * fanScale;
    final padding = dense
        ? const EdgeInsets.fromLTRB(18, 14, 18, 12)
        : (large
              ? const EdgeInsets.fromLTRB(26, 24, 26, 22)
              : const EdgeInsets.fromLTRB(20, 20, 20, 18));
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dense ? 20 : 26),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: fanHeight,
            width: fanWidth,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final (angle, offset, rank, suit, highlighted) in _fan)
                  _fanCard(
                    angle: angle * fanScale,
                    offset: offset * fanScale,
                    card: _demoCard(rank, suit),
                    highlighted: highlighted,
                    width: highlighted ? cardWidth * 1.12 : cardWidth,
                  ),
              ],
            ),
          ),
          SizedBox(height: dense ? 2 : 6),
          Text(
            '斗地主',
            style: TextStyle(
              color: kGoldSoft,
              fontSize: dense ? 26 : (large ? 44 : 38),
              fontWeight: FontWeight.w900,
              letterSpacing: dense ? 6 : (large ? 12 : 10),
              height: 1.1,
            ),
          ),
          if (!dense) ...[
            const SizedBox(height: 4),
            Text(
              '经典三人玩法 · ${level.label} AI 对手',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: large ? 12.5 : 11.5,
                letterSpacing: 1.5,
              ),
            ),
          ],
          SizedBox(height: dense ? 10 : 16),
          Container(
            padding: EdgeInsets.symmetric(vertical: dense ? 6 : 10),
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
                    _Metric(
                      label: '对局',
                      value: '${stats.games}',
                      valueSize: dense ? 15 : (large ? 20 : 17),
                    ),
                    _divider(dense: dense),
                    _Metric(
                      label: '胜率',
                      value: stats.winRateLabel,
                      valueSize: dense ? 15 : (large ? 20 : 17),
                    ),
                    _divider(dense: dense),
                    _Metric(
                      label: '积分',
                      value: '${stats.totalScore}',
                      highlight: stats.totalScore > 0,
                      valueSize: dense ? 15 : (large ? 20 : 17),
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
    required double width,
    bool highlighted = false,
  }) {
    return Transform.translate(
      offset: Offset(offset, highlighted ? -6 : 0),
      child: Transform.rotate(
        angle: angle,
        child: PlayingCardView(card: card, width: width, selected: highlighted),
      ),
    );
  }

  Widget _divider({required bool dense}) => Container(
    width: 0.6,
    height: dense ? 20 : 26,
    color: Colors.white.withValues(alpha: 0.1),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.highlight = false,
    this.valueSize = 17,
  });

  final String label;
  final String value;
  final bool highlight;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: highlight ? kGoldSoft : Colors.white,
              fontSize: valueSize,
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
  const _StartButton({required this.onPressed, this.dense = false});

  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dense ? 48 : 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.play_arrow_rounded, size: dense ? 22 : 24),
        label: Text(
          '开始对局',
          style: TextStyle(
            fontSize: dense ? 15 : 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        style: goldButtonStyle(
          padding: EdgeInsets.zero,
          fontSize: dense ? 15 : 16,
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
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: dense ? 10 : 14),
        decoration: surfacePanel(scheme),
        child: Column(
          children: [
            Icon(icon, size: dense ? 19 : 21, color: scheme.primary),
            SizedBox(height: dense ? 4 : 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 11 : 11.5,
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
