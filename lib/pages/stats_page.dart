import 'package:flutter/material.dart';

import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/confirm_dialog.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  Future<void> _reset(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: '清空生涯数据？',
      message: '对局数、胜率与积分将全部归零，此操作无法撤销。',
      confirmLabel: '清空',
    );
    if (ok) await StatsService.instance.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据统计')),
      body: ListenableBuilder(
        listenable: StatsService.instance,
        builder: (context, _) {
          final stats = StatsService.instance.stats;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _SummaryCard(stats: stats),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: '地主局数',
                      value: '${stats.landlordGames}',
                      note:
                          '胜率 ${(stats.landlordWinRate * 100).toStringAsFixed(1)}%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: '农民局数',
                      value: '${stats.peasantGames}',
                      note:
                          '胜率 ${(stats.peasantWinRate * 100).toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: '累计积分',
                      value: '${stats.totalScore}',
                      note: stats.totalScore >= 0 ? '保持盈利' : '继续加油',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: '最高连胜',
                      value: '${stats.bestStreak}',
                      note: stats.currentStreak > 0
                          ? '当前 ${stats.currentStreak} 连胜'
                          : '从下一局开始',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (stats.games > 0)
                OutlinedButton.icon(
                  onPressed: () => _reset(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('清空生涯数据'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  '数据仅保存在本机 · v${AppConstants.version}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats});

  final CareerStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C6A47), Color(0xFF0B2A1A)],
        ),
        border: Border.all(color: kGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: stats.winRate,
                    strokeWidth: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(kGold),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stats.winRateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '胜率',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '生涯战绩',
                  style: TextStyle(
                    color: kGoldSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                _line('总对局', '${stats.games} 局'),
                const SizedBox(height: 6),
                _line('胜 / 负', '${stats.wins} / ${stats.games - stats.wins}'),
                const SizedBox(height: 6),
                _line('累计积分', '${stats.totalScore}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
