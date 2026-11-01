import 'package:flutter/material.dart';

import '../game/replay.dart';
import '../models/hand_record.dart';
import '../models/playing_card.dart';
import '../theme/app_theme.dart';
import '../widgets/playing_card_view.dart';

/// 对局复盘：逐手查看三家剩余手牌、当前动作与本步倍数。
class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key, required this.record});

  final HandRecord record;

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  late final List<ReplayStep> _steps = buildReplay(widget.record);
  late final int _landlord = widget.record.humanIsLandlord
      ? 0
      : widget.record.playerNames.indexOf(widget.record.landlordName);
  var _index = 0;

  HandAction? get _action {
    final position = _index - 1;
    if (position < 0 || position >= widget.record.actions.length) return null;
    return widget.record.actions[position];
  }

  void _move(int delta) {
    setState(() {
      _index = (_index + delta).clamp(0, _steps.length - 1);
    });
  }

  String _name(int index) => index < widget.record.playerNames.length
      ? widget.record.playerNames[index]
      : '玩家$index';

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('对局复盘')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _StepHeader(step: step, action: _action),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    children: [
                      if (widget.record.initialHands.isEmpty)
                        const _MissingHandsTip()
                      else
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ReplaySeat(
                              name: _name(i),
                              hand: step.hands[i],
                              landlord: i == _landlord,
                              active: i == _action?.player,
                            ),
                          ),
                    ],
                  ),
                ),
                _StepControls(
                  index: _index,
                  count: _steps.length,
                  onPrev: _index == 0 ? null : () => _move(-1),
                  onNext: _index == _steps.length - 1 ? null : () => _move(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.action});

  final ReplayStep step;
  final HandAction? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '倍数 ×${step.multiplier}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
              ),
            ],
          ),
          if (action != null && action!.cards.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final card in action!.cards)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: PlayingCardView(card: card, width: 26),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplaySeat extends StatelessWidget {
  const _ReplaySeat({
    required this.name,
    required this.hand,
    required this.landlord,
    required this.active,
  });

  final String name;
  final List<PlayingCard> hand;
  final bool landlord;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? kGold.withValues(alpha: 0.6) : scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (landlord) ...[
                const SizedBox(width: 6),
                const Text(
                  '地主',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${hand.length} 张',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hand.isEmpty)
            Text(
              '已出完',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final card in hand)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: PlayingCardView(card: card, width: 26),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MissingHandsTip extends StatelessWidget {
  const _MissingHandsTip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: Text(
        '旧牌谱未保存开局手牌，这里仅回放动作与倍数。',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _StepControls extends StatelessWidget {
  const _StepControls({
    required this.index,
    required this.count,
    required this.onPrev,
    required this.onNext,
  });

  final int index;
  final int count;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('上一步'),
          ),
          Expanded(
            child: Text(
              '${index + 1} / $count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onNext,
            style: goldButtonStyle(),
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('下一步'),
          ),
        ],
      ),
    );
  }
}
