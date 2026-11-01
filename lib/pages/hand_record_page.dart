import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/hand_record.dart';
import '../models/playing_card.dart';
import '../services/file_system_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/playing_card_view.dart';
import '../widgets/section_card.dart';

/// 牌谱详情：结算摘要 + 逐步动作，可复制或导出为文本。
class HandRecordPage extends StatelessWidget {
  const HandRecordPage({super.key, required this.record});

  final HandRecord record;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: record.toText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('牌谱已复制到剪贴板')));
  }

  Future<void> _export(BuildContext context) async {
    final path = await FileSystemService.instance.saveExport(
      'ddz_hand_${record.id}.txt',
      record.toText(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path == null ? '导出失败，请改用复制' : '已导出到 $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('牌谱详情'),
        actions: [
          IconButton(
            tooltip: '复制牌谱',
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SummaryCard(record: record),
          const SizedBox(height: 12),
          _BottomCardsCard(cards: record.bottomCards),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '出牌记录',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '共 ${record.actions.length} 步',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (record.actions.isEmpty)
            Text(
              '这局没有留下动作记录',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < record.actions.length; i++)
              _ActionTile(index: i + 1, action: record.actions[i]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_all_outlined, size: 17),
                  label: const Text('复制牌谱'),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _export(context),
                    icon: const Icon(Icons.file_download_outlined, size: 17),
                    label: const Text('导出文件'),
                    style: goldButtonStyle(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.record});

  final HandRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final won = record.humanWon;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: won
                      ? const Color(0xFF2E7D4F).withValues(alpha: 0.14)
                      : scheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  won ? '胜利' : '惜败',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: won ? const Color(0xFF2E7D4F) : scheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                record.humanIsLandlord ? '地主' : '农民',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              if (record.revealed) ...[
                const SizedBox(width: 6),
                const Text(
                  '明牌',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${record.humanScore >= 0 ? '+' : ''}${record.humanScore}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: record.humanScore >= 0
                      ? const Color(0xFF2E7D4F)
                      : scheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record.outcomeLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          InfoRow(
            label: '时间',
            value: formatDateTime(record.startedAt),
            labelWidth: 56,
            fontSize: 11.5,
            padding: const EdgeInsets.only(top: 4),
          ),
          InfoRow(
            label: '底分',
            value: '${record.baseScore} 分 · 倍数 ×${record.multiplier}',
            labelWidth: 56,
            fontSize: 11.5,
            padding: const EdgeInsets.only(top: 4),
          ),
          InfoRow(
            label: '三家得分',
            value: [
              for (var i = 0; i < record.scores.length; i++)
                '${_playerName(i)} '
                    '${record.scores[i] >= 0 ? '+' : ''}${record.scores[i]}',
            ].join(' / '),
            labelWidth: 56,
            fontSize: 11.5,
            padding: const EdgeInsets.only(top: 4),
          ),
        ],
      ),
    );
  }

  String _playerName(int index) => index < record.playerNames.length
      ? record.playerNames[index]
      : '玩家$index';
}

class _BottomCardsCard extends StatelessWidget {
  const _BottomCardsCard({required this.cards});

  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '底牌',
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final card in cards) PlayingCardView(card: card, width: 28),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.index, required this.action});

  final int index;
  final HandAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight =
        action.type == HandActionType.play ||
        action.type == HandActionType.reveal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlight
                  ? kGold.withValues(alpha: 0.18)
                  : scheme.surfaceContainerHighest,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: highlight ? kGold : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.text,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: action.type == HandActionType.pass
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
                if (action.cards.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final card in action.cards)
                        PlayingCardView(card: card, width: 26),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
