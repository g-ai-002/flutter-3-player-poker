import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/playing_card.dart';
import '../theme/app_theme.dart';

/// 通用扑克牌面：手牌、出牌区、底牌与结算展示共用。
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    required this.width,
    this.selected = false,
    this.faceDown = false,
  });

  final PlayingCard card;
  final double width;
  final bool selected;
  final bool faceDown;

  double get height => width * 1.4;

  /// 阴影写成常量，手牌每次重建不再为每张牌重新分配 BoxShadow 与颜色。
  static const List<BoxShadow> _cardShadow = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> _selectedShadow = [
    BoxShadow(color: Color(0x52000000), blurRadius: 10, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x59D8B56A), blurRadius: 12, spreadRadius: 1),
  ];
  static const List<BoxShadow> _backShadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(math.max(4, width * 0.1));
    if (faceDown) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5C3C), Color(0xFF0C2B1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: kGold.withValues(alpha: 0.55)),
          boxShadow: _backShadow,
        ),
        child: Center(
          child: Container(
            width: width * 0.46,
            height: width * 0.62,
            decoration: BoxDecoration(
              border: Border.all(
                color: kGold.withValues(alpha: 0.45),
                width: 0.8,
              ),
              borderRadius: BorderRadius.circular(width * 0.04),
            ),
          ),
        ),
      );
    }

    final color = card.isRed ? kCardRed : kCardBlack;
    final scale = width / 54;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          colors: [kCardFaceTop, kCardFaceBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: selected ? kGold : kCardBorder,
          width: selected ? 2 : 0.9,
        ),
        boxShadow: selected ? _selectedShadow : _cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 4 * scale,
            top: 2 * scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.rankLabel,
                  style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: color,
                  ),
                ),
                Text(
                  card.suitSymbol,
                  style: TextStyle(
                    fontSize: 11 * scale,
                    height: 1.1,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (card.isJoker)
            Center(
              child: Text(
                card.rank == 17 ? '大\n王' : '小\n王',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: color,
                ),
              ),
            )
          else
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: 6 * scale),
                child: Text(
                  card.suitSymbol,
                  style: TextStyle(
                    fontSize: 26 * scale,
                    height: 1,
                    color: color,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 4 * scale,
            bottom: 2 * scale,
            child: Transform.rotate(
              angle: math.pi,
              child: Text(
                card.rankLabel,
                style: TextStyle(
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
