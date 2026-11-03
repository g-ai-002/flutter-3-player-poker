import 'package:flutter/material.dart';

import '../models/hand_record.dart';
import '../services/hand_history_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/page_frame.dart';
import 'hand_record_page.dart';

/// 牌谱列表：最近 20 局的胜负、倍数与得分，可进入详情。
class HandHistoryPage extends StatelessWidget {
  const HandHistoryPage({super.key});

  Future<void> _clear(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: '清空牌谱？',
      message: '最近的对局记录将全部删除，此操作无法撤销。',
      confirmLabel: '清空',
    );
    if (ok) await HandHistoryService.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('牌谱'),
        actions: [
          ListenableBuilder(
            listenable: HandHistoryService.instance,
            builder: (context, _) {
              final empty = HandHistoryService.instance.records.isEmpty;
              return IconButton(
                tooltip: '清空牌谱',
                onPressed: empty ? null : () => _clear(context),
                icon: const Icon(Icons.delete_outline),
              );
            },
          ),
        ],
      ),
      body: PageFrame(
        child: ListenableBuilder(
          listenable: HandHistoryService.instance,
          builder: (context, _) {
            final records = HandHistoryService.instance.records;
            if (records.isEmpty) return const _EmptyState();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final record = records[index];
                return _RecordTile(
                  record: record,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HandRecordPage(record: record),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 46,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '还没有牌谱',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '完成一局对战后，这里会保留最近 20 局的出牌记录',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final HandRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = record.humanScore;
    final scoreColor = score >= 0
        ? const Color(0xFF2E7D4F)
        : const Color(0xFFB3392E);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: record.humanIsLandlord
                      ? kGold.withValues(alpha: 0.18)
                      : scheme.primaryContainer,
                ),
                child: Text(
                  record.humanIsLandlord ? '地' : '农',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: record.humanIsLandlord
                        ? const Color(0xFF8A6414)
                        : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.outcomeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatDateTime(record.startedAt)} · '
                      '${record.actions.length} 步'
                      '${record.revealed ? ' · 明牌' : ''}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${score >= 0 ? '+' : ''}$score',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
