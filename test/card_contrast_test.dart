import 'package:flutter/material.dart';
import 'package:flutter_3_player_poker/models/playing_card.dart';
import 'package:flutter_3_player_poker/theme/app_theme.dart';
import 'package:flutter_3_player_poker/widgets/playing_card_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// WCAG AA 正文对比度下限。
const double _minContrast = 4.5;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('牌面红黑两色在牌底上的对比度达到 AA', () {
    for (final face in [kCardFaceTop, kCardFaceBottom]) {
      expect(
        _contrast(kCardRed, face),
        greaterThanOrEqualTo(_minContrast),
        reason: '红色牌点在 $face 上要清晰可读',
      );
      expect(
        _contrast(kCardBlack, face),
        greaterThanOrEqualTo(_minContrast),
        reason: '黑色牌点在 $face 上要清晰可读',
      );
    }
  });

  testWidgets('亮牌正面不带任何半透明遮挡', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Center(
            child: PlayingCardView(
              card: card(14, suit: CardSuit.heart),
              width: 52,
            ),
          ),
        ),
      ),
    );

    // 0.6.3 曾把整层牌面误包进 Opacity(0.45)，牌点发灰正是它造成的。
    expect(find.byType(Opacity), findsNothing);
    final rank = tester.widget<Text>(
      find.descendant(
        of: find.byType(PlayingCardView),
        matching: find.text('A'),
      ).first,
    );
    expect(rank.style!.color, kCardRed);
    expect(rank.style!.color!.a, 1.0);
  });

  testWidgets('黑色牌点使用纯正的黑色而不是灰绿色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Center(
            child: PlayingCardView(
              card: card(10, suit: CardSuit.spade),
              width: 52,
            ),
          ),
        ),
      ),
    );

    final rank = tester.widget<Text>(
      find.descendant(
        of: find.byType(PlayingCardView),
        matching: find.text('10'),
      ).first,
    );
    expect(rank.style!.color, kCardBlack);
    expect(rank.style!.color!.a, 1.0);
  });

  testWidgets('盖牌背面不需要亮牌配色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Center(
            child: PlayingCardView(card: card(14), width: 52, faceDown: true),
          ),
        ),
      ),
    );

    expect(find.byType(Opacity), findsNothing);
    expect(find.text('A'), findsNothing);
  });
}
