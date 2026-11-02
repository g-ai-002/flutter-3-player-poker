import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/playing_card.dart';
import 'playing_card_view.dart';

/// 扇形展开的手牌：按可用宽度自动压缩叠放间距，选中牌上抬。
///
/// 支持单击切换，也支持横向拖动连续多选：从一张牌拖到另一张牌，
/// 途经的牌会一次性选中或取消，适合快速挑选顺子、连对与飞机。
class HandView extends StatefulWidget {
  const HandView({
    super.key,
    required this.cards,
    required this.selectedIds,
    required this.onTap,
    required this.onSelectionChanged,
    this.enabled = true,
    this.maxCardWidth,
  });

  final List<PlayingCard> cards;
  final Set<int> selectedIds;
  final ValueChanged<int> onTap;
  final ValueChanged<Set<int>> onSelectionChanged;
  final bool enabled;
  final double? maxCardWidth;

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView> {
  int? _anchor;
  int? _pendingAnchor;
  bool _selecting = false;
  Set<int> _baseline = const {};

  int _indexAt(double dx, double spacing) {
    if (widget.cards.length <= 1) return 0;
    final index = spacing <= 0 ? 0 : (dx / spacing).floor();
    return index.clamp(0, widget.cards.length - 1);
  }

  void _beginDrag(DragStartDetails details, double spacing) {
    if (!widget.enabled || widget.cards.isEmpty) return;
    final index = _pendingAnchor ?? _indexAt(details.localPosition.dx, spacing);
    _anchor = index;
    _baseline = Set.of(widget.selectedIds);
    _selecting = !widget.selectedIds.contains(widget.cards[index].id);
    _applyDrag(index);
  }

  void _applyDrag(int end) {
    final anchor = _anchor;
    if (anchor == null) return;
    final from = math.min(anchor, end);
    final to = math.max(anchor, end);
    final next = Set.of(_baseline);
    for (var i = from; i <= to; i++) {
      final id = widget.cards[i].id;
      if (_selecting) {
        next.add(id);
      } else {
        next.remove(id);
      }
    }
    widget.onSelectionChanged(next);
  }

  void _endDrag() {
    _anchor = null;
    _pendingAnchor = null;
    _baseline = const {};
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return const SizedBox(height: 84);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final baseWidth =
            widget.maxCardWidth ??
            (width > 900 ? 66.0 : (width > 600 ? 60.0 : 52.0));
        final cardWidth = math.min(baseWidth, width / 3.1);
        final spacing = cards.length == 1
            ? 0.0
            : math.min(
                cardWidth * 0.62,
                math.max(11.0, (width - cardWidth) / (cards.length - 1)),
              );
        final height = cardWidth * 1.4 + 18;
        final totalWidth = cardWidth + spacing * (cards.length - 1);
        return SizedBox(
          height: height,
          child: Align(
            child: GestureDetector(
              key: const ValueKey('hand-drag-area'),
              behavior: HitTestBehavior.opaque,
              onPanDown: widget.enabled
                  ? (details) => _pendingAnchor = _indexAt(
                      details.localPosition.dx,
                      spacing,
                    )
                  : null,
              onPanStart: widget.enabled
                  ? (details) => _beginDrag(details, spacing)
                  : null,
              onPanUpdate: widget.enabled
                  ? (details) =>
                        _applyDrag(_indexAt(details.localPosition.dx, spacing))
                  : null,
              onPanEnd: widget.enabled ? (_) => _endDrag() : null,
              onPanCancel: widget.enabled ? _endDrag : null,
              child: SizedBox(
                width: totalWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < cards.length; i++)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 120),
                        left: i * spacing,
                        bottom: widget.selectedIds.contains(cards[i].id)
                            ? 16
                            : 0,
                        child: GestureDetector(
                          key: ValueKey('hand-card-${cards[i].id}'),
                          onTap: widget.enabled
                              ? () => widget.onTap(cards[i].id)
                              : null,
                          child: PlayingCardView(
                            card: cards[i],
                            width: cardWidth,
                            selected: widget.selectedIds.contains(cards[i].id),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
