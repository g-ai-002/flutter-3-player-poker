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
    this.dimmed = false,
  });

  final PlayingCard card;
  final double width;
  final bool selected;
  final bool faceDown;
  final bool dimmed;

  double get height => width * 1.4;

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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

    final color = card.isRed
        ? const Color(0xFFC0392B)
        : const Color(0xFF1F2A24);
    final scale = width / 54;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFEF9), Color(0xFFF1E9D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: selected ? kGold : const Color(0xFFD8CEB6),
          width: selected ? 2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.32 : 0.18),
            blurRadius: selected ? 10 : 4,
            offset: Offset(0, selected ? 4 : 2),
          ),
          if (selected)
            BoxShadow(
              color: kGold.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
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
                      color: color.withValues(alpha: 0.9),
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
                    color: color.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
